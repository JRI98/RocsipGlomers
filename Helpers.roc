import pf.Stdin
import pf.Stdout
import pf.Stderr

Helpers :: [].{
	encode_json : a -> Str where [a.encoder_for : _ -> (a, _ -> Try(_, _))]
	encode_json = |a| Json.to_str(a)

	decode_json : Str -> a where [a.parser_for : _ -> (_ -> Try({ value : a, rest : _ }, _))]
	decode_json = |str| {
		match Json.parse(str) {
			Ok(p) => p
			Err(_) => {
				crash "Json.parse(str)"
			}
		}
	}

	NodeState(a) : { node_id : Str, msg_id : U64, ..a }

	reply! : NodeState(a), Payload({ msg_id : U64, ..t }), { msg_id : U64, in_reply_to : U64, .. } => Try(NodeState(a), _)
	reply! = |state, msg, body| {
		send_message!(state, msg.src, { ..body, in_reply_to: msg.body.msg_id })
	}

	send_message! : NodeState(a), Str, { msg_id : U64, .. } => Try(NodeState(a), _)
	send_message! = |state, dest, body| {
		payload = encode_json({ src: state.node_id, dest, body: { ..body, msg_id: state.msg_id } })
		Stdout.line!(payload)
		Ok({ ..state, msg_id: state.msg_id + 1 })
	}

	Payload(body) : {
		src : Str,
		dest : Str,
		body : body,
	}

	LoopState(a) : [WaitingForInit, ..a]

	run! = |handle_input!| {
		initial_state : LoopState(_)
		initial_state = WaitingForInit

		run_internal!(handle_input!, initial_state)
	}

	run_internal! = |handle_input!, state| {
		line_str = Stdin.line!()

		Stderr.line!(line_str)

		new_state = handle_input!(line_str, state)?
		run_internal!(handle_input!, new_state)
	}
}
