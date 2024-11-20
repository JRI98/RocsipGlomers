app [main] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.16.0/O00IPk-Krg_diNS2dVWlI0ZQP794Vctxzv0ha96mK0E.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.11.0/z45Wzc-J39TLNweQUoLw3IGZtkQiEN3lTBv3BXErRjQ.tar.br",
}

import Helpers exposing [run, decodeJSON, reply, Payload]

NodeState : [State { nodeId : Str, nodeIds : List Str, msgId : U64 }]

LoopState : [WaitingForInit, Running NodeState]

handleInput : Str, LoopState -> Task LoopState _
handleInput = \input, loopState ->
    when loopState is
        WaitingForInit ->
            payload : Payload { type : Str, msgId : U64, nodeId : Str, nodeIds : List Str }
            payload = decodeJSON input

            stateFromInit : NodeState
            stateFromInit = State { nodeId: payload.body.nodeId, nodeIds: payload.body.nodeIds, msgId: 0 }

            nodeState = reply! stateFromInit payload { type: "init_ok", msgId: 0, inReplyTo: 0 }

            Task.ok (Running nodeState)

        Running nodeState ->
            payload : Payload { type : Str, msgId : U64 }
            payload = decodeJSON input

            newNodeState = reply! nodeState payload { msgId: 0, inReplyTo: 0, type: "generate_ok", id: Str.concat payload.src (Num.toStr payload.body.msgId) }

            Task.ok (Running newNodeState)

main =
    run handleInput
