import pf.Stdin
import pf.Stdout
import pf.Stderr

Helpers :: [].{
	encode_json : a -> Str where [a.encoder_for : _]
	encode_json = |a| Json.to_str(a)

	decode_json : Str -> a where [a.parser_for : _]
	decode_json = |str| {
		match Json.parse(str) {
			Ok(p) => p
			Err(_) => {
				crash "Json.parse(str)"
			}
		}
	}

	NodeState(a) : { node_id : Str, msg_id : U64, ..a }

	send_message! = |state, dest, body| {
		payload = encode_json({ src: state.node_id, dest, body })
		Stdout.line!(payload)?
		Ok({ ..state, msg_id: state.msg_id + 1 })
	}

	Payload(body) : {
		src : Str,
		dest : Str,
		body : body,
	}

	run! = |handle_input!, state| {
		line_str = Stdin.line!()?

		Stderr.line!(line_str)?

		new_state = handle_input!(line_str, state)?
		run!(handle_input!, new_state)
	}
}
