%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math import unsigned_div_rem

struct InstructionSet {
    instructions_len: felt,
    instructions: felt*,
}

func get_frame_instruction_set{syscall_ptr: felt*, range_check_ptr}(
    cycle: felt,
    instructions_sets_len: felt,
    instructions_sets: felt*,
    instructions: felt*,
    frame_instructions_len: felt,
    frame_instructions: felt*,
    offset: felt,
) {
    if (instructions_sets_len == 0) {
        return ();
    }
    tempvar l = [instructions_sets];
    let (_, r) = unsigned_div_rem(cycle, l);
    assert [frame_instructions + frame_instructions_len] = [instructions + r + offset];
    return get_frame_instruction_set(
        cycle,
        instructions_sets_len - 1,
        instructions_sets + 1,
        instructions,
        frame_instructions_len + 1,
        frame_instructions,
        offset + l,
    );
}
