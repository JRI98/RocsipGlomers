app [main] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.10.2/FH4N0Sw-JSFXJfG3j54VEDPtXOoN-6I9v_IA8S18IGk.tar.br",
}

import Helpers exposing [run, decodeJSON, reply, Payload]

NodeState : [State { nodeId : Str, nodeIds : List Str, msgId : U64, storage : { messages : List U64 } }]

# TODO(https://github.com/roc-lang/roc/issues/5294): Dict Str (List Str)
Topology : {
    n0 : List Str,
}

NodeTopology : [Topology Topology]

LoopState : [WaitingForInit, WaitingForTopology NodeState, Running NodeState NodeTopology]

handleInput : Str, LoopState -> Task LoopState _
handleInput = \input, loopState ->
    when loopState is
        WaitingForInit ->
            payload : Payload { type : Str, msgId : U64, nodeId : Str, nodeIds : List Str }
            payload = decodeJSON input
            body = payload.body

            stateFromInit : NodeState
            stateFromInit = State { nodeId: body.nodeId, nodeIds: body.nodeIds, msgId: 0, storage: { messages: [] } }

            nodeState = reply! stateFromInit payload { type: "init_ok", msgId: 0, inReplyTo: 0 }

            Task.ok (WaitingForTopology nodeState)

        WaitingForTopology nodeState ->
            payload : Payload { type : Str, msgId : U64, topology : Topology }
            payload = decodeJSON input

            topologyFromTopology : NodeTopology
            topologyFromTopology = Topology payload.body.topology

            newNodeState = reply! nodeState payload { type: "topology_ok", msgId: 0, inReplyTo: 0 }

            Task.ok (Running newNodeState topologyFromTopology)

        Running nodeState topology ->
            typePayload : Payload { type : Str, msgId : U64 }
            typePayload = decodeJSON input
            bodyType = typePayload.body.type

            (State unwrappedNodeState) = nodeState
            storage = unwrappedNodeState.storage

            replyInfo : [
                Broadcast (Payload { type : Str, msgId : U64, message : U64 }, { type : Str, msgId : U64, inReplyTo : U64 }, NodeState),
                Read (Payload { type : Str, msgId : U64 }, { type : Str, msgId : U64, inReplyTo : U64, messages : List U64 }, NodeState),
            ]
            replyInfo =
                when bodyType is
                    "broadcast" ->
                        p : Payload { type : Str, msgId : U64, message : U64 }
                        p = decodeJSON input
                        body = p.body

                        newMessages = List.append storage.messages body.message
                        newStorage = { storage & messages: newMessages }

                        Broadcast (p, { type: "broadcast_ok", msgId: 0, inReplyTo: 0 }, State { unwrappedNodeState & storage: newStorage })

                    "read" ->
                        p : Payload { type : Str, msgId : U64 }
                        p = decodeJSON input

                        Read (p, { type: "read_ok", msgId: 0, inReplyTo: 0, messages: storage.messages }, nodeState)

                    bt -> crash "replyInfo: $(bt)"

            newNodeStateTask =
                when replyInfo is
                    Broadcast (payload, p, ns) ->
                        reply ns payload p

                    Read (payload, p, ns) ->
                        reply ns payload p

            newNodeState = newNodeStateTask!

            Task.ok (Running newNodeState topology)

main =
    run handleInput
