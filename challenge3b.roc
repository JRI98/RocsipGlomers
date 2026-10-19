app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.IOErr
import Helpers exposing [Payload, decode_json, run!, send_message!]

NodeState : {
	node_id : Str,
	neighbors : List(Str),
	msg_id : U64,
	messages : Set(U64),
}

LoopState : [
	WaitingForInit,
	WaitingForTopology(NodeState),
	Running(NodeState),
]

broadcast_to_neighbors! : NodeState, Str, U64 => Try(NodeState, [StdoutErr(IOErr)])
broadcast_to_neighbors! = |state, exclude, message| {
	var $ns = state
	for neighbor in state.neighbors {
		if neighbor != exclude {
			$ns = send_message!($ns, neighbor, { msg_id: $ns.msg_id, type: "broadcast_node", message })?
		}
	}
	Ok($ns)
}

handle_input! : Str, LoopState => Try(LoopState, [StdoutErr(IOErr)])
handle_input! = |input, loop_state| {
	match loop_state {
		WaitingForInit => {
			payload : Payload({ type : Str, msg_id : U64, node_id : Str })
			payload = decode_json(input)

			state_from_init : NodeState
			state_from_init = { node_id: payload.body.node_id, neighbors: [], msg_id: 0, messages: Set.empty() }

			node_state = send_message!(
				state_from_init,
				payload.src,
				{ msg_id: state_from_init.msg_id, in_reply_to: payload.body.msg_id, type: "init_ok" },
			)?

			Ok(WaitingForTopology(node_state))
		}

		WaitingForTopology(node_state) => {
			payload : Payload({ type : Str, msg_id : U64, topology : Dict(Str, List(Str)) })
			payload = decode_json(input)

			neighbors =
				match Dict.get(payload.body.topology, node_state.node_id) {
					Ok(n) => n
					Err(_) => []
				}

			new_node_state = send_message!(
				{ ..node_state, neighbors },
				payload.src,
				{ msg_id: node_state.msg_id, in_reply_to: payload.body.msg_id, type: "topology_ok" },
			)?

			Ok(Running(new_node_state))
		}

		Running(node_state) => {
			type_payload : Payload({ type : Str })
			type_payload = decode_json(input)

			new_node_state =
				match type_payload.body.type {
					"broadcast" => {
						p : Payload({ type : Str, msg_id : U64, message : U64 })
						p = decode_json(input)

						is_new = !Set.contains(node_state.messages, p.body.message)
						state_with_msg = { ..node_state, messages: Set.insert(node_state.messages, p.body.message) }

						ns_after_reply = send_message!(
							state_with_msg,
							p.src,
							{ msg_id: state_with_msg.msg_id, in_reply_to: p.body.msg_id, type: "broadcast_ok" },
						)?

						if is_new {
							broadcast_to_neighbors!(ns_after_reply, p.src, p.body.message)?
						} else {
							ns_after_reply
						}
					}

					"broadcast_node" => {
						p : Payload({ type : Str, msg_id : U64, message : U64 })
						p = decode_json(input)

						is_new = !Set.contains(node_state.messages, p.body.message)
						state_with_msg = { ..node_state, messages: Set.insert(node_state.messages, p.body.message) }

						ns_after_reply = send_message!(
							state_with_msg,
							p.src,
							{ msg_id: state_with_msg.msg_id, in_reply_to: p.body.msg_id, type: "broadcast_node_ok" },
						)?

						if is_new {
							broadcast_to_neighbors!(ns_after_reply, p.src, p.body.message)?
						} else {
							ns_after_reply
						}
					}

					"broadcast_node_ok" => {
						node_state
					}

					"read" => {
						p : Payload({ type : Str, msg_id : U64 })
						p = decode_json(input)

						send_message!(
							node_state,
							p.src,
							{ msg_id: node_state.msg_id, in_reply_to: p.body.msg_id, type: "read_ok", messages: Set.to_list(node_state.messages) },
						)?
					}

					_ => {
						node_state
					}
				}

			Ok(Running(new_node_state))
		}
	}
}

main! = |_| {
	run!(handle_input!)
}
