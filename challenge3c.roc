app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.12.0/1trwx8sltQ-e9Y2rOB4LWUWLS_sFVyETK8Twl0i9qpw.tar.gz",
}

import Helpers exposing [run!, decode_json, reply!, send_message!, Payload]

NodeState : [State { node_id : Str, node_ids : List Str, msg_id : U64, storage : { messages : Set U64, neighbors_messages : Dict Str (Set U64) } }]

# TODO(https://github.com/roc-lang/roc/issues/5294): Dict Str (List Str)
Topology : {
    n0 : List Str,
    n1 : List Str,
    n2 : List Str,
    n3 : List Str,
    n4 : List Str,
}

NodeTopology : [Topology Topology]

LoopState : [WaitingForInit, WaitingForTopology NodeState, Running NodeState NodeTopology]

ReplyInfo : [
    Broadcast (Payload { type : Str, msg_id : U64, message : U64 }, List [BroadcastOk { type : Str, msg_id : U64, in_reply_to : U64 }, BroadcastNode (Str, { type : Str, msg_id : U64, messages : List U64 })], NodeState),
    Read (Payload { type : Str, msg_id : U64 }, { type : Str, msg_id : U64, in_reply_to : U64, messages : List U64 }, NodeState),
    BroadcastNode (Payload { type : Str, msg_id : U64, messages : List U64 }, List [BroadcastNodeOk { type : Str, msg_id : U64, in_reply_to : U64 }, BroadcastNode (Str, { type : Str, msg_id : U64, messages : List U64 })], NodeState),
    BroadcastNodeOk NodeState,
]

running_send_reply! : ReplyInfo => Result NodeState _
running_send_reply! = |info|
    when info is
        Broadcast((_, [], ns)) | BroadcastNode((_, [], ns)) ->
            Ok(ns)

        Broadcast((payload, [BroadcastOk(p), .. as rest], ns)) ->
            new_ns = try(reply!, ns, payload, p)
            running_send_reply!(Broadcast((payload, rest, new_ns)))

        Broadcast((payload, [BroadcastNode((dest, p)), .. as rest], ns)) ->
            new_ns = try(send_message!, ns, dest, p)
            running_send_reply!(Broadcast((payload, rest, new_ns)))

        Read((payload, p, ns)) ->
            new_ns = try(reply!, ns, payload, p)
            Ok(new_ns)

        BroadcastNode((payload, [BroadcastNodeOk(p), .. as rest], ns)) ->
            new_ns = try(reply!, ns, payload, p)
            running_send_reply!(BroadcastNode((payload, rest, new_ns)))

        BroadcastNode((payload, [BroadcastNode((dest, p)), .. as rest], ns)) ->
            new_ns = try(send_message!, ns, dest, p)
            running_send_reply!(BroadcastNode((payload, rest, new_ns)))

        BroadcastNodeOk(ns) ->
            Ok(ns)

handle_input! : Str, LoopState => Result LoopState _
handle_input! = |input, loop_state|
    when loop_state is
        WaitingForInit ->
            payload : Payload { type : Str, msg_id : U64, node_id : Str, node_ids : List Str }
            payload = decode_json(input)

            state_from_init : NodeState
            state_from_init = State({ node_id: payload.body.node_id, node_ids: payload.body.node_ids, msg_id: 0, storage: { messages: Set.empty({}), neighbors_messages: Dict.empty({}) } })

            node_state = try(reply!, state_from_init, payload, { type: "init_ok", msg_id: 0, in_reply_to: 0 })

            Ok(WaitingForTopology(node_state))

        WaitingForTopology(node_state) ->
            payload : Payload { type : Str, msg_id : U64, topology : Topology }
            payload = decode_json(input)
            body = payload.body

            topology_from_topology : NodeTopology
            topology_from_topology = Topology(body.topology)

            State(unwrapped_node_state) = node_state

            neighbors =
                when unwrapped_node_state.node_id is
                    "n0" -> body.topology.n0
                    "n1" -> body.topology.n1
                    "n2" -> body.topology.n2
                    "n3" -> body.topology.n3
                    "n4" -> body.topology.n4
                    n ->
                        crash("neighbors: ${n}")

            neighbors_messages = Dict.from_list(List.map(neighbors, |n| (n, Set.empty({}))))

            new_node_state = try(reply!, node_state, payload, { type: "topology_ok", msg_id: 0, in_reply_to: 0 })

            State(unwrapped_new_node_state) = new_node_state
            storage = unwrapped_new_node_state.storage
            new_storage = { storage & neighbors_messages }

            Ok(Running(State({ unwrapped_new_node_state & storage: new_storage }), topology_from_topology))

        Running(node_state, topology) ->
            type_payload : Payload { type : Str, msg_id : U64 }
            type_payload = decode_json(input)
            body_type = type_payload.body.type

            State(unwrapped_node_state) = node_state
            storage = unwrapped_node_state.storage

            reply_info : ReplyInfo
            reply_info =
                when body_type is
                    "broadcast" ->
                        p : Payload { type : Str, msg_id : U64, message : U64 }
                        p = decode_json(input)
                        message = p.body.message

                        updated_neighbors_messages = storage.neighbors_messages

                        (messages_to_neighbors, new_neighbors_messages) = Dict.walk(
                            updated_neighbors_messages,
                            ([], updated_neighbors_messages),
                            |(msgs, n_msgs), k, v|
                                if
                                    Set.contains(v, message)
                                then
                                    (msgs, n_msgs)
                                else
                                    (List.append(msgs, BroadcastNode((k, { type: "broadcast_node", msg_id: 0, messages: [message] }))), add_to_dict_set(n_msgs, k, [message])),
                        )

                        new_messages = Set.insert(storage.messages, message)
                        new_storage = { storage & messages: new_messages, neighbors_messages: new_neighbors_messages }

                        Broadcast(
                            (p, List.concat([BroadcastOk({ type: "broadcast_ok", msg_id: 0, in_reply_to: 0 })], messages_to_neighbors), State({ unwrapped_node_state & storage: new_storage })),
                        )

                    "read" ->
                        p : Payload { type : Str, msg_id : U64 }
                        p = decode_json(input)

                        Read((p, { type: "read_ok", msg_id: 0, in_reply_to: 0, messages: Set.to_list(storage.messages) }, node_state))

                    "broadcast_node" ->
                        p : Payload { type : Str, msg_id : U64, messages : List U64 }
                        p = decode_json(input)
                        messages = p.body.messages

                        updated_neighbors_messages = add_to_dict_set(storage.neighbors_messages, p.src, messages)

                        (messages_to_neighbors, new_neighbors_messages) = Dict.walk(
                            updated_neighbors_messages,
                            ([], updated_neighbors_messages),
                            |(msgs, n_msgs), k, v|
                                missing_messages = Set.difference(Set.from_list(messages), v)
                                if
                                    Set.len(missing_messages) == 0
                                then
                                    (msgs, n_msgs)
                                else
                                    (List.append(msgs, BroadcastNode((k, { type: "broadcast_node", msg_id: 0, messages: Set.to_list(missing_messages) }))), add_to_dict_set(n_msgs, k, messages)),
                        )

                        new_messages = Set.union(storage.messages, Set.from_list(messages))
                        new_storage = { storage & messages: new_messages, neighbors_messages: new_neighbors_messages }

                        BroadcastNode(
                            (p, List.concat([BroadcastNodeOk({ type: "broadcast_node_ok", msg_id: 0, in_reply_to: 0 })], messages_to_neighbors), State({ unwrapped_node_state & storage: new_storage })),
                        )

                    "broadcast_node_ok" ->
                        p : Payload { type : Str, msg_id : U64, in_reply_to : U64 }
                        p = decode_json(input)

                        BroadcastNodeOk(node_state)

                    bt -> crash("handlePayload: ${bt}")

            new_node_state = try(running_send_reply!, reply_info)

            Ok(Running(new_node_state, topology))

add_to_dict_set : Dict a (Set b), a, List b -> Dict a (Set b)
add_to_dict_set = |dict, k, vs|
    entry =
        when Dict.get(dict, k) is
            Ok(e) -> e
            Err(err) ->
                err_str = Inspect.to_str(err)
                crash("addToDictSet: ${err_str}")

    Dict.insert(dict, k, Set.union(entry, Set.from_list(vs)))

main! = |_|
    try(run!, handle_input!)
