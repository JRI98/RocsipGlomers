app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.IOErr
import Helpers exposing [Payload, decode_json, run!, send_message!]

NodeState : {
	node_id : Str,
	msg_id : U64,
	logs : Dict(Str, List((U64, U64))),
	committed : Dict(Str, U64),
}

handle_input! : Str, NodeState => Try(NodeState, [StdoutErr(IOErr)])
handle_input! = |input, node_state| {
	type_payload : Payload({ type : Str })
	type_payload = decode_json(input)

	new_node_state =
		match type_payload.body.type {
			"init" => {
				payload : Payload({ type : Str, msg_id : U64, node_id : Str })
				payload = decode_json(input)

				send_message!(
					{ ..node_state, node_id: payload.body.node_id },
					payload.src,
					{ msg_id: node_state.msg_id, in_reply_to: payload.body.msg_id, type: "init_ok" },
				)?
			}

			"send" => {
				p : Payload({ msg_id : U64, key : Str, msg : U64 })
				p = decode_json(input)

				log =
					match Dict.get(node_state.logs, p.body.key) {
						Ok(l) => l
						Err(_) => []
					}
				offset = List.len(log)
				new_log = List.append(log, (offset, p.body.msg))
				new_logs = Dict.insert(node_state.logs, p.body.key, new_log)
				state_with_log = { ..node_state, logs: new_logs }

				send_message!(
					state_with_log,
					p.src,
					{ msg_id: state_with_log.msg_id, in_reply_to: p.body.msg_id, type: "send_ok", offset },
				)?
			}

			"poll" => {
				p : Payload({ msg_id : U64, offsets : Dict(Str, U64) })
				p = decode_json(input)

				var $msgs = Dict.empty()
				for (k, from_offset) in Dict.to_list(p.body.offsets) {
					match Dict.get(node_state.logs, k) {
						Ok(log) => {
							matching = List.keep_if(log, |(off, _)| off >= from_offset)
							if !List.is_empty(matching) {
								$msgs = Dict.insert($msgs, k, matching)
							}
						}

						Err(_) => {}
					}
				}

				send_message!(
					node_state,
					p.src,
					{ msg_id: node_state.msg_id, in_reply_to: p.body.msg_id, type: "poll_ok", msgs: $msgs },
				)?
			}

			"commit_offsets" => {
				p : Payload({ msg_id : U64, offsets : Dict(Str, U64) })
				p = decode_json(input)

				var $committed = node_state.committed
				for (k, offset) in Dict.to_list(p.body.offsets) {
					old_offset =
						match Dict.get($committed, k) {
							Ok(o) => o
							Err(_) => 0
						}
					new_offset = if offset > old_offset {
						offset
					} else {
						old_offset
					}
					$committed = Dict.insert($committed, k, new_offset)
				}
				state_with_committed = { ..node_state, committed: $committed }

				send_message!(
					state_with_committed,
					p.src,
					{ msg_id: state_with_committed.msg_id, in_reply_to: p.body.msg_id, type: "commit_offsets_ok" },
				)?
			}

			"list_committed_offsets" => {
				p : Payload({ msg_id : U64, keys : List(Str) })
				p = decode_json(input)

				var $offsets = Dict.empty()
				for k in p.body.keys {
					match Dict.get(node_state.committed, k) {
						Ok(offset) => {
							$offsets = Dict.insert($offsets, k, offset)
						}

						Err(_) => {}
					}
				}

				send_message!(
					node_state,
					p.src,
					{ msg_id: node_state.msg_id, in_reply_to: p.body.msg_id, type: "list_committed_offsets_ok", offsets: $offsets },
				)?
			}

			_ => node_state
		}

	Ok(new_node_state)
}

main! = |_| {
	run!(
		handle_input!,
		{
			node_id: "",
			msg_id: 0,
			logs: Dict.empty(),
			committed: Dict.empty(),
		},
	)
}
