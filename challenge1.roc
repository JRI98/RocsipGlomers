app [main] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.15.0/SlwdbJ-3GR7uBWQo6zlmYWNYOxnvo8r6YABXD-45UOw.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.10.2/FH4N0Sw-JSFXJfG3j54VEDPtXOoN-6I9v_IA8S18IGk.tar.br",
}

import Helpers exposing [run, decodeJSON, reply, Payload]

NodeState : [State { nodeId : Str, msgId : U64 }]

RunState : [WaitingForInit, Running NodeState]

handleInput : Str, RunState -> Task RunState _
handleInput = \input, runState ->
    when runState is
        WaitingForInit ->
            payload : Payload { type : Str, msgId : U64, nodeId : Str, nodeIds : List Str }
            payload = decodeJSON input

            stateFromInit : NodeState
            stateFromInit = State { nodeId: payload.body.nodeId, msgId: 0 }

            nodeState = reply! stateFromInit payload { type: "init_ok", msgId: 0, inReplyTo: 0 }

            Task.ok (Running nodeState)

        Running nodeState ->
            payload : Payload { type : Str, msgId : U64, echo : Str }
            payload = decodeJSON input

            newNodeState = reply! nodeState payload { type: "echo_ok", msgId: 0, inReplyTo: 0, echo: payload.body.echo }

            Task.ok (Running newNodeState)

main =
    run handleInput
