app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
}

import Helpers exposing [run!, decode_json, reply!, Payload]

NodeState : { node_id : Str, node_ids : List(Str), msg_id : U64, storage : { messages : List(U64) } }

NodeTopology : Dict(Str, (List(Str)))

LoopState : [WaitingForInit, WaitingForTopology(NodeState), Running(NodeState, NodeTopology)]

handle_input! : Str, LoopState => Try(LoopState, _)
handle_input! = |input, loop_state| {
	match loop_state {
		WaitingForInit => {
			payload : Payload({ type : Str, msg_id : U64, node_id : Str, node_ids : List(Str) })
			payload = decode_json(input)
			body = payload.body

			state_from_init : NodeState
			state_from_init = { node_id: body.node_id, node_ids: body.node_ids, msg_id: 0, storage: { messages: [] } }

			node_state = reply!(state_from_init, payload, { msg_id: 0, in_reply_to: 0, type: "init_ok" })?

			Ok(WaitingForTopology(node_state))
		}

		WaitingForTopology(node_state) => {
			payload : Payload({ type : Str, msg_id : U64, topology : NodeTopology })
			payload = decode_json(input)

			new_node_state = reply!(node_state, payload, { msg_id: 0, in_reply_to: 0, type: "topology_ok" })?

			Ok(Running(new_node_state, payload.body.topology))
		}

		Running(node_state, topology) => {
			type_payload : Payload({ type : Str, msg_id : U64 })
			type_payload = decode_json(input)
			body_type = type_payload.body.type

			storage = node_state.storage

			new_node_state = 
				match body_type {
					"broadcast" => {
						p : Payload({ type : Str, msg_id : U64, message : U64 })
						p = decode_json(input)
						body = p.body

						new_messages = List.append(storage.messages, body.message)
						new_storage = { ..storage, messages: new_messages }

						reply!({ ..node_state, storage: new_storage }, p, { msg_id: 0, in_reply_to: 0, type: "broadcast_ok" })?
					}

					"read" => {
						p : Payload({ type : Str, msg_id : U64 })
						p = decode_json(input)

						reply!(node_state, p, { msg_id: 0, in_reply_to: 0, type: "read_ok", messages: storage.messages })?
					}

					_ => {
						crash "body_type"
					}
				}

			Ok(Running(new_node_state, topology))
		}
	}
}

main! = |_| {
	run!(handle_input!)
}
