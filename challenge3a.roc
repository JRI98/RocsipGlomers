app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.12.0/1trwx8sltQ-e9Y2rOB4LWUWLS_sFVyETK8Twl0i9qpw.tar.gz",
}

import Helpers exposing [run!, decode_json, reply!, Payload]

NodeState : [State { node_id : Str, node_ids : List Str, msg_id : U64, storage : { messages : List U64 } }]

# TODO(https://github.com/roc-lang/roc/issues/5294): Dict Str (List Str)
Topology : {
    n0 : List Str,
}

NodeTopology : [Topology Topology]

LoopState : [WaitingForInit, WaitingForTopology NodeState, Running NodeState NodeTopology]

handle_input! : Str, LoopState => Result LoopState _
handle_input! = |input, loop_state|
    when loop_state is
        WaitingForInit ->
            payload : Payload { type : Str, msg_id : U64, node_id : Str, node_ids : List Str }
            payload = decode_json(input)
            body = payload.body

            state_from_init : NodeState
            state_from_init = State({ node_id: body.node_id, node_ids: body.node_ids, msg_id: 0, storage: { messages: [] } })

            node_state = try(reply!, state_from_init, payload, { type: "init_ok", msg_id: 0, in_reply_to: 0 })

            Ok(WaitingForTopology(node_state))

        WaitingForTopology(node_state) ->
            payload : Payload { type : Str, msg_id : U64, topology : Topology }
            payload = decode_json(input)

            topology_from_topology : NodeTopology
            topology_from_topology = Topology(payload.body.topology)

            new_node_state = try(reply!, node_state, payload, { type: "topology_ok", msg_id: 0, in_reply_to: 0 })

            Ok(Running(new_node_state, topology_from_topology))

        Running(node_state, topology) ->
            type_payload : Payload { type : Str, msg_id : U64 }
            type_payload = decode_json(input)
            body_type = type_payload.body.type

            State(unwrapped_node_state) = node_state
            storage = unwrapped_node_state.storage

            reply_info : [
                Broadcast (Payload { type : Str, msg_id : U64, message : U64 }, { type : Str, msg_id : U64, in_reply_to : U64 }, NodeState),
                Read (Payload { type : Str, msg_id : U64 }, { type : Str, msg_id : U64, in_reply_to : U64, messages : List U64 }, NodeState),
            ]
            reply_info =
                when body_type is
                    "broadcast" ->
                        p : Payload { type : Str, msg_id : U64, message : U64 }
                        p = decode_json(input)
                        body = p.body

                        new_messages = List.append(storage.messages, body.message)
                        new_storage = { storage & messages: new_messages }

                        Broadcast((p, { type: "broadcast_ok", msg_id: 0, in_reply_to: 0 }, State({ unwrapped_node_state & storage: new_storage })))

                    "read" ->
                        p : Payload { type : Str, msg_id : U64 }
                        p = decode_json(input)

                        Read((p, { type: "read_ok", msg_id: 0, in_reply_to: 0, messages: storage.messages }, node_state))

                    bt -> crash("replyInfo: ${bt}")

            new_node_state =
                when reply_info is
                    Broadcast((payload, p, ns)) ->
                        try(reply!, ns, payload, p)

                    Read((payload, p, ns)) ->
                        try(reply!, ns, payload, p)

            Ok(Running(new_node_state, topology))

main! = |_|
    try(run!, handle_input!)
