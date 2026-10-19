app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.IOErr
import Helpers exposing [Payload, decode_json, run!, send_message!]

NodeState : {
	node_id : Str,
	msg_id : U64,
}

handle_input! : Str, NodeState => Try(NodeState, [StdoutErr(IOErr)])
handle_input! = |input, node_state| {
	type_payload : Payload({ type : Str })
	type_payload = decode_json(input)

	new_node_state =
		match type_payload.body.type {
			"init" => {
				payload : Payload({ msg_id : U64, node_id : Str })
				payload = decode_json(input)

				send_message!(
					{ ..node_state, node_id: payload.body.node_id },
					payload.src,
					{ msg_id: node_state.msg_id, in_reply_to: payload.body.msg_id, type: "init_ok" },
				)?
			}

			"echo" => {
				payload : Payload({ msg_id : U64, echo : Str })
				payload = decode_json(input)

				send_message!(
					node_state,
					payload.src,
					{ msg_id: node_state.msg_id, in_reply_to: payload.body.msg_id, type: "echo_ok", echo: payload.body.echo },
				)?
			}

			_ => node_state
		}

	Ok(new_node_state)
}

main! = |_| {
	run!(handle_input!, { node_id: "", msg_id: 0 })
}
