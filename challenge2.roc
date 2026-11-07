app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.27.0/9yjxqdGTP4xSpSEmDazwTmRsehfRZzA19pwEKkR6fj1g.tar.zst",
}

import pf.IOErr
import Helpers exposing [Payload, decode_json, run!, send_message!]

NodeState : {
	node_id : Str,
	msg_id : U64,
}

handle_input! : Str, NodeState => Try(NodeState, [Interrupted, StdoutErr(IOErr)])
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

			"generate" => {
				payload : Payload({ msg_id : U64 })
				payload = decode_json(input)

				send_message!(
					node_state,
					payload.src,
					{
						msg_id: node_state.msg_id,
						in_reply_to: payload.body.msg_id,
						type: "generate_ok",
						id: "${node_state.node_id}-${node_state.msg_id.to_str()}",
					},
				)?
			}

			_ => node_state
		}

	Ok(new_node_state)
}

main! = |_| {
	run!(handle_input!, { node_id: "", msg_id: 0 })
}
