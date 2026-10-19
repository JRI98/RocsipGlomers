app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.IOErr
import Helpers exposing [Payload, decode_json, run!, send_message!]

NodeState : {
	node_id : Str,
	msg_id : U64,
}

LoopState : [
	WaitingForInit,
	Running(NodeState),
]

handle_input! : Str, LoopState => Try(LoopState, [StdoutErr(IOErr)])
handle_input! = |input, loop_state| {
	match loop_state {
		WaitingForInit => {
			payload : Payload({ type : Str, msg_id : U64, node_id : Str })
			payload = decode_json(input)

			state_from_init : NodeState
			state_from_init = { node_id: payload.body.node_id, msg_id: 0 }

			node_state = send_message!(
				state_from_init,
				payload.src,
				{ msg_id: state_from_init.msg_id, in_reply_to: payload.body.msg_id, type: "init_ok" },
			)?

			Ok(Running(node_state))
		}

		Running(node_state) => {
			payload : Payload({ type : Str, msg_id : U64 })
			payload = decode_json(input)

			new_node_state = send_message!(
				node_state,
				payload.src,
				{
					msg_id: node_state.msg_id,
					in_reply_to: payload.body.msg_id,
					type: "generate_ok",
					id: "${node_state.node_id}-${node_state.msg_id.to_str()}",
				},
			)?

			Ok(Running(new_node_state))
		}
	}
}

main! = |_| {
	run!(handle_input!)
}
