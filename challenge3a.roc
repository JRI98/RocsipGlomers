app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.IOErr
import Helpers exposing [Payload, decode_json, run!, send_message!]

NodeState : { node_id : Str, node_ids : List(Str), msg_id : U64, storage : { messages : List(U64) } }

NodeTopology : Dict(Str, (List(Str)))

LoopState : [WaitingForInit, WaitingForTopology(NodeState), Running(NodeState, NodeTopology)]

handle_input! : Str, LoopState => Try(LoopState, [StdoutErr(IOErr)])
handle_input! = |input, loop_state| {
	match loop_state {
		WaitingForInit => {
			payload : Payload({ type : Str, msg_id : U64, node_id : Str, node_ids : List(Str) })
			payload = decode_json(input)
			body = payload.body

			state_from_init : NodeState
			state_from_init = { node_id: body.node_id, node_ids: body.node_ids, msg_id: 0, storage: { messages: [] } }

			node_state = send_message!(
				state_from_init,
				payload.src,
				{ msg_id: state_from_init.msg_id, in_reply_to: payload.body.msg_id, type: "init_ok" },
			)?

			Ok(WaitingForTopology(node_state))
		}

		WaitingForTopology(node_state) => {
			payload : Payload({ type : Str, msg_id : U64, topology : NodeTopology })
			payload = decode_json(input)

			new_node_state = send_message!(
				node_state,
				payload.src,
				{ msg_id: node_state.msg_id, in_reply_to: payload.body.msg_id, type: "topology_ok" },
			)?

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
						state_with_storage = { ..node_state, storage: new_storage }

						send_message!(
							state_with_storage,
							p.src,
							{ msg_id: state_with_storage.msg_id, in_reply_to: p.body.msg_id, type: "broadcast_ok" },
						)?
					}

					"read" => {
						p : Payload({ type : Str, msg_id : U64 })
						p = decode_json(input)

						send_message!(
							node_state,
							p.src,
							{ msg_id: node_state.msg_id, in_reply_to: p.body.msg_id, type: "read_ok", messages: storage.messages },
						)?
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
