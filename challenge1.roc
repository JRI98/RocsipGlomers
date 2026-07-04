app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
}

import Helpers exposing [run!, decode_json, reply!, Payload]

NodeState : { node_id : Str, msg_id : U64 }

LoopState : [WaitingForInit, Running(NodeState)]

handle_input! : Str, LoopState => Try(LoopState, _)
handle_input! = |input, loop_state| {
	match loop_state {
		WaitingForInit => {
			payload : Payload({ type : Str, msg_id : U64, node_id : Str, node_ids : List(Str) })
			payload = decode_json(input)

			state_from_init : NodeState
			state_from_init = { node_id: payload.body.node_id, msg_id: 0 }

			node_state = reply!(state_from_init, payload, { msg_id: 0, in_reply_to: 0, type: "init_ok" })?

			Ok(Running(node_state))
		}

		Running(node_state) => {
			payload : Payload({ type : Str, msg_id : U64, echo : Str })
			payload = decode_json(input)

			new_node_state = reply!(node_state, payload, { msg_id: 0, in_reply_to: 0, type: "echo_ok", echo: payload.body.echo })?

			Ok(Running(new_node_state))
		}
	}
}

main! = |_| {
	run!(handle_input!)
}
