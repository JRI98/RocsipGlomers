app [main!] {
	pf: platform "https://github.com/lukewilliamboswell/roc-platform-template-zig/releases/download/0.9/8GdFEvQYS3TeAZxKvTzCLVdQiomweGtXcdZkXNDEeABq.tar.zst",
}

import Helpers exposing [run!, decode_json, reply!, send_message!, Payload]

NodeState : { node_id : Str, node_ids : List(Str), msg_id : U64, storage : { messages : Set(U64), neighbors_messages : Dict(Str, Set(U64)) } }

NodeTopology : Dict(Str, (List(Str)))

LoopState : [WaitingForInit, WaitingForTopology(NodeState), Running(NodeState, NodeTopology)]

handle_input! : Str, LoopState => Try(LoopState, _)
handle_input! = |input, loop_state| {
	match loop_state {
		WaitingForInit => {
			payload : Payload({ type : Str, msg_id : U64, node_id : Str, node_ids : List(Str) })
			payload = decode_json(input)

			state_from_init : NodeState
			state_from_init = { node_id: payload.body.node_id, node_ids: payload.body.node_ids, msg_id: 0, storage: { messages: Set.empty(), neighbors_messages: Dict.empty() } }

			node_state = reply!(state_from_init, payload, { msg_id: 0, in_reply_to: 0, type: "init_ok" })?

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

			new_node_state = reply!(node_state, payload, { msg_id: 0, in_reply_to: 0, type: "topology_ok" })?

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

						(messages_to_neighbors, new_neighbors_messages) = Dict.fold(
							updated_neighbors_messages,
							([], updated_neighbors_messages),
							|(msgs, n_msgs), k, v| {
								if Set.contains(v, message) {
									(msgs, n_msgs)
								} else {
									(List.append(msgs, (k, { msg_id: 0, message: message, type: "broadcast_node" })), add_to_dict_set(n_msgs, k, message))
								}
							},
						)

						new_messages = Set.insert(node_state.storage.messages, message)
						new_storage = { ..node_state.storage, messages: new_messages, neighbors_messages: new_neighbors_messages }

						ns_after_reply = reply!({ ..node_state, storage: new_storage }, p, { msg_id: 0, in_reply_to: 0, type: "broadcast_ok" })?

						var $ns = ns_after_reply
						for (neighbor, msg) in messages_to_neighbors {
							$ns = send_message!($ns, neighbor, msg)?
						}
						$ns
					}

					"read" => {
						p : Payload({ type : Str, msg_id : U64 })
						p = decode_json(input)

						reply!(node_state, p, { msg_id: 0, in_reply_to: 0, messages: Set.to_list(node_state.storage.messages), type: "read_ok" })?
					}

					"broadcast_node" => {
						p : Payload({ type : Str, msg_id : U64, message : U64 })
						p = decode_json(input)
						message = p.body.message

						updated_neighbors_messages = add_to_dict_set(node_state.storage.neighbors_messages, p.src, message)

						(messages_to_neighbors, new_neighbors_messages) = Dict.fold(
							updated_neighbors_messages,
							([], updated_neighbors_messages),
							|(msgs, n_msgs), k, v| {
								if Set.contains(v, message) {
									(msgs, n_msgs)
								} else {
									(List.append(msgs, (k, { msg_id: 0, message: message, type: "broadcast_node" })), add_to_dict_set(n_msgs, k, message))
								}
							},
						)

						new_messages = Set.insert(node_state.storage.messages, message)
						new_storage = { ..node_state.storage, messages: new_messages, neighbors_messages: new_neighbors_messages }

						ns_after_reply = reply!({ ..node_state, storage: new_storage }, p, { msg_id: 0, in_reply_to: 0, type: "broadcast_node_ok" })?

						var $ns = ns_after_reply
						for (neighbor, msg) in messages_to_neighbors {
							$ns = send_message!($ns, neighbor, msg)?
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
	where [
		a.is_eq : a, a -> Bool,
		a.to_hash : a, Hasher -> Hasher,
		b.is_eq : b, b -> Bool,
	]
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
