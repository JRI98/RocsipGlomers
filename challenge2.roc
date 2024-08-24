app [main] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.14.0/dC5ceT962N_4jmoyoffVdphJ_4GlW3YMhAPyGPr-nU0.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.10.1/jozYCvOqoYa-cV6OdTcxw3uDGn61cLvzr5dK1iKf1ag.tar.br",
}

import pf.Task exposing [Task]
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
