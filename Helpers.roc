module [run!, decode_json, reply!, send_message!, Payload]

import pf.Stdin
import pf.Stdout
import pf.Stderr
import json.Json

json_coder = Json.utf8_with({ field_name_mapping: SnakeCase, skip_missing_properties: Bool.true })

encode_json : a -> Str where a implements Encoding
encode_json = |a|
    when Str.from_utf8(Encode.to_bytes(a, json_coder)) is
        Ok(o) -> o
        Err(err) ->
            err_str = Inspect.to_str(err)
            crash("encodeJSON: ${err_str}")

decode_json : Str -> a where a implements Decoding
decode_json = |str|
    when Decode.from_bytes(Str.to_utf8(str), json_coder) is
        Ok(p) -> p
        Err(err) ->
            err_str = Inspect.to_str(err)
            crash("decodeJSON: ${err_str}")

NodeState a : [State { node_id : Str, msg_id : U64 }a]

reply! : NodeState a, { src : Str, body : { msg_id : U64 }* }*, { msg_id : U64, in_reply_to : U64 }* => Result (NodeState a) _
reply! = |state, msg, body|
    send_message!(state, msg.src, { body & in_reply_to: msg.body.msg_id })

send_message! : NodeState a, Str, { msg_id : U64 }* => Result (NodeState a) _
send_message! = |State(state), dest, body|
    payload = encode_json(
        {
            src: state.node_id,
            dest,
            body: { body & msg_id: state.msg_id },
        },
    )
    try(Stdout.line!, payload)

    Ok(State({ state & msg_id: state.msg_id + 1 }))

Payload body : {
    src : Str,
    dest : Str,
    body : body,
}

LoopState a : [WaitingForInit]a

run! = |handle_input!|
    initial_state : LoopState _
    initial_state = WaitingForInit

    run_internal!(handle_input!, initial_state)

run_internal! = |handle_input!, state|
    line_str = try(Stdin.line!, {})

    try(Stderr.line!, line_str)

    new_state = try(handle_input!, line_str, state)

    run_internal!(handle_input!, new_state)
