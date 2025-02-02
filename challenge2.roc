app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.12.0/1trwx8sltQ-e9Y2rOB4LWUWLS_sFVyETK8Twl0i9qpw.tar.gz",
}

import Helpers exposing [run!, decode_json, reply!, Payload]

NodeState : [State { node_id : Str, node_ids : List Str, msg_id : U64 }]

LoopState : [WaitingForInit, Running NodeState]

handle_input! : Str, LoopState => Result LoopState _
handle_input! = |input, loop_state|
    when loop_state is
        WaitingForInit ->
            payload : Payload { type : Str, msg_id : U64, node_id : Str, node_ids : List Str }
            payload = decode_json(input)

            state_from_init : NodeState
            state_from_init = State({ node_id: payload.body.node_id, node_ids: payload.body.node_ids, msg_id: 0 })

            node_state = try(reply!, state_from_init, payload, { type: "init_ok", msg_id: 0, in_reply_to: 0 })

            Ok(Running(node_state))

        Running(node_state) ->
            payload : Payload { type : Str, msg_id : U64 }
            payload = decode_json(input)

            new_node_state = try(reply!, node_state, payload, { msg_id: 0, in_reply_to: 0, type: "generate_ok", id: Str.concat(payload.src, Num.to_str(payload.body.msg_id)) })

            Ok(Running(new_node_state))

main! = |_|
    try(run!, handle_input!)
