app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.IOErr
import pf.Cmd exposing [Child]
import Helpers exposing [Payload, decode_json, run!, send_message!]

NodeState : {
	node_id : Str,
	neighbors : List(Str),
	msg_id : U64,
	messages : Set(U64),
	acked : Dict(Str, Set(U64)),
	ticker : List(Child),
}

LoopState : [
	WaitingForInit,
	Running(NodeState),
]

tree_neighbors : Str, List(Str) -> List(Str)
tree_neighbors = |node_id, node_ids| {
	idx =
		match List.find_first_index(node_ids, |id| id == node_id) {
			Ok(i) => i
			Err(_) => 0
		}
	parent =
		if idx > 0 {
			match List.get(node_ids, (idx - 1) // 5) {
				Ok(p) => [p]
				Err(_) => []
			}
		} else {
			[]
		}
	children =
		[1, 2, 3, 4, 5]
			|> List.keep_oks(|offset| List.get(node_ids, idx * 5 + offset))
	List.concat(parent, children)
}

gossip_to_neighbors! : NodeState, Str => Try(NodeState, [StdoutErr(IOErr)])
gossip_to_neighbors! = |state, exclude| {
	var $ns = state
	for neighbor in state.neighbors {
		if neighbor != exclude {
			acked_for_neighbor =
				match Dict.get($ns.acked, neighbor) {
					Ok(s) => s
					Err(_) => Set.empty()
				}
			unacked = Set.difference($ns.messages, acked_for_neighbor)
			if !Set.is_empty(unacked) {
				$ns = send_message!(
					$ns,
					neighbor,
					{ msg_id: $ns.msg_id, type: "gossip", messages: Set.to_list(unacked) },
				)?
			}
		}
	}
	Ok($ns)
}

add_to_acked : Dict(Str, Set(U64)), Str, List(U64) -> Dict(Str, Set(U64))
add_to_acked = |acked, peer, msgs| {
	current =
		match Dict.get(acked, peer) {
			Ok(s) => s
			Err(_) => Set.empty()
		}
	Dict.insert(acked, peer, Set.union(current, Set.from_list(msgs)))
}

handle_input! : Str, LoopState => Try(LoopState, [StdoutErr(IOErr)])
handle_input! = |input, loop_state| {
	match loop_state {
		WaitingForInit => {
			payload : Payload({ type : Str, msg_id : U64, node_id : Str, node_ids : List(Str) })
			payload = decode_json(input)

			neighbors = tree_neighbors(payload.body.node_id, payload.body.node_ids)
			acked = Dict.from_list(List.map(neighbors, |n| (n, Set.empty())))

			cmd_str = "while true; do sleep 2; echo '{\"src\":\"${payload.body.node_id}\",\"dest\":\"${payload.body.node_id}\",\"body\":{\"type\":\"tick\"}}'; done"
			cmd = Cmd.new_str("sh").args_str(["-c", cmd_str]).manage_tree(Bool.True)
			ticker =
				match Cmd.spawn!(cmd) {
					Ok(c) => [c]
					Err(_) => []
				}

			state_from_init : NodeState
			state_from_init = {
				node_id: payload.body.node_id,
				neighbors,
				msg_id: 0,
				messages: Set.empty(),
				acked,
				ticker,
			}

			node_state = send_message!(
				state_from_init,
				payload.src,
				{ msg_id: state_from_init.msg_id, in_reply_to: payload.body.msg_id, type: "init_ok" },
			)?

			Ok(Running(node_state))
		}

		Running(node_state) => {
			type_payload : Payload({ type : Str })
			type_payload = decode_json(input)

			new_node_state =
				match type_payload.body.type {
					"topology" => {
						p : Payload({ msg_id : U64 })
						p = decode_json(input)

						send_message!(
							node_state,
							p.src,
							{ msg_id: node_state.msg_id, in_reply_to: p.body.msg_id, type: "topology_ok" },
						)?
					}

					"broadcast" => {
						p : Payload({ type : Str, msg_id : U64, message : U64 })
						p = decode_json(input)

						state_with_msg = { ..node_state, messages: Set.insert(node_state.messages, p.body.message) }

						ns_after_reply = send_message!(
							state_with_msg,
							p.src,
							{ msg_id: state_with_msg.msg_id, in_reply_to: p.body.msg_id, type: "broadcast_ok" },
						)?

						gossip_to_neighbors!(ns_after_reply, "")?
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

					"gossip" => {
						p : Payload({ type : Str, msg_id : U64, messages : List(U64) })
						p = decode_json(input)

						incoming_set = Set.from_list(p.body.messages)
						new_msgs = Set.difference(incoming_set, node_state.messages)

						new_messages = Set.union(node_state.messages, incoming_set)
						new_acked = add_to_acked(node_state.acked, p.src, p.body.messages)
						state_with_msgs = { ..node_state, messages: new_messages, acked: new_acked }

						ns_after_reply = send_message!(
							state_with_msgs,
							p.src,
							{ msg_id: state_with_msgs.msg_id, in_reply_to: p.body.msg_id, type: "gossip_ok", messages: p.body.messages },
						)?

						if !Set.is_empty(new_msgs) {
							gossip_to_neighbors!(ns_after_reply, p.src)?
						} else {
							ns_after_reply
						}
					}

					"gossip_ok" => {
						p : Payload({ type : Str, messages : List(U64) })
						p = decode_json(input)

						new_acked = add_to_acked(node_state.acked, p.src, p.body.messages)
						{ ..node_state, acked: new_acked }
					}

					"tick" => {
						gossip_to_neighbors!(node_state, "")?
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
