%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read

from contracts.simulator.mechs import MechState

struct InstructionSet {
    instructions_len: felt,
    instructions: felt*,
}

// @notice Returns the current frame instructions for each mech
// @param cycle The current frame number
// @param i The current mech
// @param mechs The dictionary of mechs
// @param instructions_sets The total amount of instructions for each mech
// @param instructions The array of all mechs instructions
// @param frame_instructions The current frame's instructions
// @param offset The offset for each mech's instructions in instructions array
func get_frame_instruction_set{range_check_ptr}(
    cycle: felt,
    i: felt,
    mechs: DictAccess*,
    instructions_sets_len: felt,
    instructions_sets: felt*,
    instructions: felt*,
    frame_instructions_len: felt,
    frame_instructions: felt*,
    offset: felt,
) -> (mechs_new: DictAccess*) {
    if (instructions_sets_len == 0) {
        return (mechs_new=mechs);
    }
    tempvar l = [instructions_sets];
    let (ptr) = dict_read{dict_ptr=mechs}(key=i);
    tempvar mech = cast(ptr, MechState*);
    let (_, r) = unsigned_div_rem(cycle + mech.pc, l);
    assert [frame_instructions + frame_instructions_len] = [instructions + r + offset];
    return get_frame_instruction_set(
        cycle,
        i + 1,
        mechs,
        instructions_sets_len - 1,
        instructions_sets + 1,
        instructions,
        frame_instructions_len + 1,
        frame_instructions,
        offset + l,
    );
}
