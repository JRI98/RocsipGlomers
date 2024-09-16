app [main] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.10.2/FH4N0Sw-JSFXJfG3j54VEDPtXOoN-6I9v_IA8S18IGk.tar.br",
}

import Helpers exposing [run, decodeJSON, reply, sendMessage, Payload]

NodeState : [State { nodeId : Str, nodeIds : List Str, msgId : U64, storage : { messages : Set U64, neighborsMessages : Dict Str (Set U64) } }]

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

handleInput : Str, LoopState -> Task LoopState _
handleInput = \input, loopState ->
    when loopState is
        WaitingForInit ->
            payload : Payload { type : Str, msgId : U64, nodeId : Str, nodeIds : List Str }
            payload = decodeJSON input

            stateFromInit : NodeState
            stateFromInit = State { nodeId: payload.body.nodeId, nodeIds: payload.body.nodeIds, msgId: 0, storage: { messages: Set.empty {}, neighborsMessages: Dict.empty {} } }

            nodeState = reply! stateFromInit payload { type: "init_ok", msgId: 0, inReplyTo: 0 }

            Task.ok (WaitingForTopology nodeState)

        WaitingForTopology nodeState ->
            payload : Payload { type : Str, msgId : U64, topology : Topology }
            payload = decodeJSON input
            body = payload.body

            topologyFromTopology : NodeTopology
            topologyFromTopology = Topology body.topology

            (State unwrappedNodeState) = nodeState

            neighbors =
                when unwrappedNodeState.nodeId is
                    "n0" -> body.topology.n0
                    "n1" -> body.topology.n1
                    "n2" -> body.topology.n2
                    "n3" -> body.topology.n3
                    "n4" -> body.topology.n4
                    n ->
                        crash "neighbors: $(n)"

            neighborsMessages = Dict.fromList (List.map neighbors (\n -> (n, Set.empty {})))

            newNodeState = reply! nodeState payload { type: "topology_ok", msgId: 0, inReplyTo: 0 }

            (State unwrappedNewNodeState) = newNodeState
            storage = unwrappedNewNodeState.storage
            newStorage = { storage & neighborsMessages }

            Task.ok (Running (State { unwrappedNewNodeState & storage: newStorage }) topologyFromTopology)

        Running nodeState topology ->
            typePayload : Payload { type : Str, msgId : U64 }
            typePayload = decodeJSON input
            bodyType = typePayload.body.type

            (State unwrappedNodeState) = nodeState
            storage = unwrappedNodeState.storage

            replyInfo : [
                Broadcast (Payload { type : Str, msgId : U64, message : U64 }, List [BroadcastOk { type : Str, msgId : U64, inReplyTo : U64 }, BroadcastNode (Str, { type : Str, msgId : U64, message : U64 })], NodeState),
                Read (Payload { type : Str, msgId : U64 }, { type : Str, msgId : U64, inReplyTo : U64, messages : List U64 }, NodeState),
                BroadcastNode (Payload { type : Str, msgId : U64, message : U64 }, List [BroadcastNodeOk { type : Str, msgId : U64, inReplyTo : U64 }, BroadcastNode (Str, { type : Str, msgId : U64, message : U64 })], NodeState),
                BroadcastNodeOk NodeState,
            ]
            replyInfo =
                when bodyType is
                    "broadcast" ->
                        p : Payload { type : Str, msgId : U64, message : U64 }
                        p = decodeJSON input
                        message = p.body.message

                        updatedNeighborsMessages = storage.neighborsMessages

                        (messagesToNeighbors, newNeighborsMessages) = Dict.walk
                            updatedNeighborsMessages
                            ([], updatedNeighborsMessages)
                            (\(msgs, nMsgs), k, v ->
                                if
                                    Set.contains v message
                                then
                                    (msgs, nMsgs)
                                else
                                    (List.append msgs (BroadcastNode (k, { type: "broadcast_node", msgId: 0, message: message })), addToDictSet nMsgs k message)
                            )

                        newMessages = Set.insert storage.messages message
                        newStorage = { storage & messages: newMessages, neighborsMessages: newNeighborsMessages }

                        Broadcast
                            (p, List.concat [BroadcastOk { type: "broadcast_ok", msgId: 0, inReplyTo: 0 }] messagesToNeighbors, State { unwrappedNodeState & storage: newStorage })

                    "read" ->
                        p : Payload { type : Str, msgId : U64 }
                        p = decodeJSON input

                        Read (p, { type: "read_ok", msgId: 0, inReplyTo: 0, messages: Set.toList storage.messages }, nodeState)

                    "broadcast_node" ->
                        p : Payload { type : Str, msgId : U64, message : U64 }
                        p = decodeJSON input
                        message = p.body.message

                        updatedNeighborsMessages = addToDictSet storage.neighborsMessages p.src message

                        (messagesToNeighbors, newNeighborsMessages) = Dict.walk
                            updatedNeighborsMessages
                            ([], updatedNeighborsMessages)
                            (\(msgs, nMsgs), k, v ->
                                if
                                    Set.contains v message
                                then
                                    (msgs, nMsgs)
                                else
                                    (List.append msgs (BroadcastNode (k, { type: "broadcast_node", msgId: 0, message: message })), addToDictSet nMsgs k message)
                            )

                        newMessages = Set.insert storage.messages message
                        newStorage = { storage & messages: newMessages, neighborsMessages: newNeighborsMessages }

                        BroadcastNode
                            (p, List.concat [BroadcastNodeOk { type: "broadcast_node_ok", msgId: 0, inReplyTo: 0 }] messagesToNeighbors, State { unwrappedNodeState & storage: newStorage })

                    "broadcast_node_ok" ->
                        BroadcastNodeOk nodeState

                    bt -> crash "handlePayload: $(bt)"

            newNodeState = Task.loop!
                replyInfo
                (\info ->
                    when info is
                        Broadcast (_, [], ns) | BroadcastNode (_, [], ns) ->
                            Task.ok (Done ns)

                        Broadcast (payload, [BroadcastOk p, .. as rest], ns) ->
                            newNs = reply! ns payload p
                            Task.ok (Step (Broadcast (payload, rest, newNs)))

                        Broadcast (payload, [BroadcastNode (dest, p), .. as rest], ns) ->
                            newNs = sendMessage! ns dest p
                            Task.ok (Step (Broadcast (payload, rest, newNs)))

                        Read (payload, p, ns) ->
                            newNs = reply! ns payload p
                            Task.ok (Done newNs)

                        BroadcastNode (payload, [BroadcastNodeOk p, .. as rest], ns) ->
                            newNs = reply! ns payload p
                            Task.ok (Step (BroadcastNode (payload, rest, newNs)))

                        BroadcastNode (payload, [BroadcastNode (dest, p), .. as rest], ns) ->
                            newNs = sendMessage! ns dest p
                            Task.ok (Step (BroadcastNode (payload, rest, newNs)))

                        BroadcastNodeOk ns ->
                            Task.ok (Done ns)

                )

            Task.ok (Running newNodeState topology)

addToDictSet : Dict a (Set b), a, b -> Dict a (Set b)
addToDictSet = \dict, k, v ->
    entry =
        when Dict.get dict k is
            Ok e -> e
            Err err ->
                errStr = Inspect.toStr err
                crash "addToDictSet: $(errStr)"

    Dict.insert dict k (Set.insert entry v)

main =
    run handleInput
