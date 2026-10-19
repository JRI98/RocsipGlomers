app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.25.0/CZsY7tYZwR3rj9kYbpaCfxki2yVAaRL8bBwMLvB2xkbA.tar.zst",
}

import pf.IOErr
import pf.Cmd exposing [Child]
import Helpers exposing [Payload, decode_json, run!, send_message!]

NodeState : {
	node_id : Str,
	all_nodes : List(Str),
	msg_id : U64,
	cached_values : Dict(Str, U64),
	pending_reads : Dict(U64, Str),
	ticker : List(Child),
}

get_node_value : Dict(Str, U64), Str -> U64
get_node_value = |cached, id| {
	match Dict.get(cached, id) {
		Ok(v) => v
		Err(_) => 0
	}
}

compute_total : NodeState -> U64
compute_total = |state| {
	var $total = 0
	for id in state.all_nodes {
		$total = $total + get_node_value(state.cached_values, id)
	}
	$total
}

sync_seq_kv! : NodeState => Try(NodeState, [StdoutErr(IOErr)])
sync_seq_kv! = |state| {
	my_value = get_node_value(state.cached_values, state.node_id)
	state_after_write = send_message!(
		state,
		"seq-kv",
		{ msg_id: state.msg_id, type: "write", key: state.node_id, value: my_value },
	)?

	var $curr = state_after_write
	for peer in state_after_write.all_nodes {
		if peer != state_after_write.node_id {
			req_id = $curr.msg_id
			with_pending = { ..$curr, pending_reads: Dict.insert($curr.pending_reads, req_id, peer) }
			$curr = send_message!(
				with_pending,
				"seq-kv",
				{ msg_id: req_id, type: "read", key: peer },
			)?
		}
	}
	Ok($curr)
}

handle_input! : Str, NodeState => Try(NodeState, [StdoutErr(IOErr)])
handle_input! = |input, node_state| {
	type_payload : Payload({ type : Str })
	type_payload = decode_json(input)

	new_node_state =
		match type_payload.body.type {
			"init" => {
				payload : Payload({ type : Str, msg_id : U64, node_id : Str, node_ids : List(Str) })
				payload = decode_json(input)

				cmd_str = "while true; do sleep 1; echo '{\"src\":\"${payload.body.node_id}\",\"dest\":\"${payload.body.node_id}\",\"body\":{\"type\":\"tick\"}}'; done"
				cmd = Cmd.new_str("sh").args_str(["-c", cmd_str]).manage_tree(Bool.True)
				ticker =
					match Cmd.spawn!(cmd) {
						Ok(c) => [c]
						Err(_) => []
					}

				state_from_init = {
					..node_state,
					node_id: payload.body.node_id,
					all_nodes: payload.body.node_ids,
					ticker,
				}

				send_message!(
					state_from_init,
					payload.src,
					{ msg_id: state_from_init.msg_id, in_reply_to: payload.body.msg_id, type: "init_ok" },
				)?
			}

			"add" => {
				p : Payload({ msg_id : U64, delta : U64 })
				p = decode_json(input)

				current = get_node_value(node_state.cached_values, node_state.node_id)
				new_cached = Dict.insert(node_state.cached_values, node_state.node_id, current + p.body.delta)
				state_with_val = { ..node_state, cached_values: new_cached }

				send_message!(
					state_with_val,
					p.src,
					{ msg_id: state_with_val.msg_id, in_reply_to: p.body.msg_id, type: "add_ok" },
				)?
			}

			"read" => {
				p : Payload({ msg_id : U64 })
				p = decode_json(input)

				total_value = compute_total(node_state)

				send_message!(
					node_state,
					p.src,
					{ msg_id: node_state.msg_id, in_reply_to: p.body.msg_id, type: "read_ok", value: total_value },
				)?
			}

			"read_ok" => {
				p : Payload({ in_reply_to : U64, value : U64 })
				p = decode_json(input)

				match Dict.get(node_state.pending_reads, p.body.in_reply_to) {
					Ok(peer_id) => {
						old_val = get_node_value(node_state.cached_values, peer_id)
						new_val = if p.body.value > old_val {
							p.body.value
						} else {
							old_val
						}
						new_cached = Dict.insert(node_state.cached_values, peer_id, new_val)
						new_pending = Dict.remove(node_state.pending_reads, p.body.in_reply_to)
						{ ..node_state, cached_values: new_cached, pending_reads: new_pending }
					}

					Err(_) => node_state
				}
			}

			"tick" => {
				sync_seq_kv!(node_state)?
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
			all_nodes: [],
			msg_id: 0,
			cached_values: Dict.empty(),
			pending_reads: Dict.empty(),
			ticker: [],
		},
	)
}
