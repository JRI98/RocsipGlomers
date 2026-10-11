app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.IOErr
import Helpers exposing [Payload, decode_json, run!, send_message!]

NodeState : { node_id : Str, node_ids : List(Str), msg_id : U64, storage : { messages : Set(U64), neighbors_messages : Dict(Str, Set(U64)) } }

NodeTopology : Dict(Str, (List(Str)))

LoopState : [WaitingForInit, WaitingForTopology(NodeState), Running(NodeState, NodeTopology)]

handle_input! : Str, LoopState => Try(LoopState, [StdoutErr(IOErr)])
handle_input! = |input, loop_state| {
	match loop_state {
		WaitingForInit => {
			payload : Payload({ type : Str, msg_id : U64, node_id : Str, node_ids : List(Str) })
			payload = decode_json(input)

			state_from_init : NodeState
			state_from_init = { node_id: payload.body.node_id, node_ids: payload.body.node_ids, msg_id: 0, storage: { messages: Set.empty(), neighbors_messages: Dict.empty() } }

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

			neighbors =
				match Dict.get(payload.body.topology, node_state.node_id) {
					Ok(n) => n
					Err(_) => {
						crash "Dict.get(payload.body.topology, node_state.node_id)"
					}
				}

			neighbors_messages = Dict.from_list(List.map(neighbors, |n| (n, Set.empty())))

			new_node_state = send_message!(
				node_state,
				payload.src,
				{ msg_id: node_state.msg_id, in_reply_to: payload.body.msg_id, type: "topology_ok" },
			)?

			new_storage = { ..new_node_state.storage, neighbors_messages }

			Ok(Running({ ..new_node_state, storage: new_storage }, payload.body.topology))
		}

		Running(node_state, topology) => {
			type_payload : Payload({ type : Str, msg_id : U64 })
			type_payload = decode_json(input)

			new_node_state =
				match type_payload.body.type {
					"broadcast" => {
						p : Payload({ type : Str, msg_id : U64, message : U64 })
						p = decode_json(input)
						message = p.body.message

						updated_neighbors_messages = node_state.storage.neighbors_messages

						(neighbors_to_broadcast, new_neighbors_messages) = Dict.fold(
							updated_neighbors_messages,
							([], updated_neighbors_messages),
							|(neighbors_list, n_msgs), k, v| {
								if Set.contains(v, message) {
									(neighbors_list, n_msgs)
								} else {
									(List.append(neighbors_list, k), add_to_dict_set(n_msgs, k, message))
								}
							},
						)

						new_messages = Set.insert(node_state.storage.messages, message)
						new_storage = { ..node_state.storage, messages: new_messages, neighbors_messages: new_neighbors_messages }
						state_with_storage = { ..node_state, storage: new_storage }

						ns_after_reply = send_message!(
							state_with_storage,
							p.src,
							{ msg_id: state_with_storage.msg_id, in_reply_to: p.body.msg_id, type: "broadcast_ok" },
						)?

						var $ns = ns_after_reply
						for neighbor in neighbors_to_broadcast {
							$ns = send_message!($ns, neighbor, { msg_id: $ns.msg_id, message: message, type: "broadcast_node" })?
						}
						$ns
					}

					"read" => {
						p : Payload({ type : Str, msg_id : U64 })
						p = decode_json(input)

						send_message!(
							node_state,
							p.src,
							{ msg_id: node_state.msg_id, in_reply_to: p.body.msg_id, messages: Set.to_list(node_state.storage.messages), type: "read_ok" },
						)?
					}

					"broadcast_node" => {
						p : Payload({ type : Str, msg_id : U64, message : U64 })
						p = decode_json(input)
						message = p.body.message

						updated_neighbors_messages = add_to_dict_set(node_state.storage.neighbors_messages, p.src, message)

						(neighbors_to_broadcast, new_neighbors_messages) = Dict.fold(
							updated_neighbors_messages,
							([], updated_neighbors_messages),
							|(neighbors_list, n_msgs), k, v| {
								if Set.contains(v, message) {
									(neighbors_list, n_msgs)
								} else {
									(List.append(neighbors_list, k), add_to_dict_set(n_msgs, k, message))
								}
							},
						)

						new_messages = Set.insert(node_state.storage.messages, message)
						new_storage = { ..node_state.storage, messages: new_messages, neighbors_messages: new_neighbors_messages }
						state_with_storage = { ..node_state, storage: new_storage }

						ns_after_reply = send_message!(
							state_with_storage,
							p.src,
							{ msg_id: state_with_storage.msg_id, in_reply_to: p.body.msg_id, type: "broadcast_node_ok" },
						)?

						var $ns = ns_after_reply
						for neighbor in neighbors_to_broadcast {
							$ns = send_message!($ns, neighbor, { msg_id: $ns.msg_id, message: message, type: "broadcast_node" })?
						}
						$ns
					}

					"broadcast_node_ok" => {
						node_state
					}

					_ => {
						crash "type_payload.body.type"
					}
				}

			Ok(Running(new_node_state, topology))
		}
	}
}

add_to_dict_set : Dict(a, Set(b)), a, b -> Dict(a, Set(b))
	where [a.is_eq : _, a.to_hash : _, b.is_eq : _, b.to_hash : _]
add_to_dict_set = |dict, k, v| {
	entry =
		match Dict.get(dict, k) {
			Ok(e) => e
			Err(_) => {
				crash "Dict.get(dict, k)"
			}
		}

	Dict.insert(dict, k, Set.insert(entry, v))
}

main! = |_| {
	run!(handle_input!)
}
