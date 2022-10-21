%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import abs_value, unsigned_div_rem
from starkware.cairo.common.memcpy import memcpy

namespace ns_mech_status {
    const OPEN = 0;
    const CLOSE = 1;
}

namespace ns_mech_type {
    const MECH_SIZE = 4;

    const SINGLETON = 0;

    const STATIC_COST_SINGLETON = 150;

    func get_mechs_cost{range_check_ptr}(mechs_len: felt, mechs: MechState*, sum: felt) -> felt {
        if (mechs_len == 0) {
            return sum;
        }
        tempvar cost;
        tempvar mech = [mechs];
        if (mech.type == SINGLETON) {
            assert cost = STATIC_COST_SINGLETON;
        }
        return get_mechs_cost(mechs_len - 1, mechs + MECH_SIZE, sum + cost);
    }
}

namespace ns_atom_status {
    const FREE = 0;
    const POSSESSED = 1;
    const DELIVERED = 2;
    const CONSUMED = 3;
}

namespace ns_atom_type {
    const VANILLA = 0;
    const HAZELNUT = 1;
    const CHOCOLATE = 2;
    const TRUFFLE = 3;
}

namespace ns_operator_type {
    const STIR = 0;
    const SHAKE = 1;
    const STEAM = 2;

    const STATIC_COST_STIR = 250;
    const STATIC_COST_SHAKE = 500;
    const STATIC_COST_STEAM = 750;

    func stir{}() -> (stir: OperatorType) {
        let (input_atoms: felt*) = alloc();
        assert input_atoms[0] = ns_atom_type.VANILLA;
        assert input_atoms[1] = ns_atom_type.VANILLA;
        let (output_atoms: felt*) = alloc();
        assert output_atoms[0] = ns_atom_type.HAZELNUT;

        let stir = OperatorType(
            input_atoms_len=2,
            input_atoms=input_atoms,
            output_atoms_len=1,
            output_atoms=output_atoms,
        );
        return (stir=stir);
    }
    func shake{}() -> (stir: OperatorType) {
        let (input_atoms: felt*) = alloc();
        assert input_atoms[0] = ns_atom_type.HAZELNUT;
        assert input_atoms[1] = ns_atom_type.HAZELNUT;
        let (output_atoms: felt*) = alloc();
        assert output_atoms[0] = ns_atom_type.CHOCOLATE;

        let stir = OperatorType(
            input_atoms_len=2,
            input_atoms=input_atoms,
            output_atoms_len=1,
            output_atoms=output_atoms,
        );
        return (stir=stir);
    }
    func steam{}() -> (stir: OperatorType) {
        let (input_atoms: felt*) = alloc();
        assert input_atoms[0] = ns_atom_type.HAZELNUT;
        assert input_atoms[1] = ns_atom_type.CHOCOLATE;
        assert input_atoms[2] = ns_atom_type.CHOCOLATE;
        let (output_atoms: felt*) = alloc();
        assert output_atoms[0] = ns_atom_type.TRUFFLE;
        assert output_atoms[1] = ns_atom_type.VANILLA;

        let stir = OperatorType(
            input_atoms_len=3,
            input_atoms=input_atoms,
            output_atoms_len=2,
            output_atoms=output_atoms,
        );
        return (stir=stir);
    }

    func get_operators_cost{range_check_ptr}(
        operators_type_len: felt, operators_type: felt*, sum: felt
    ) -> felt {
        if (operators_type_len == 0) {
            return sum;
        }
        tempvar cost;
        tempvar operator_type = [operators_type];
        if (operator_type == STIR) {
            assert cost = STATIC_COST_STIR;
        }
        if (operator_type == SHAKE) {
            assert cost = STATIC_COST_SHAKE;
        }
        if (operator_type == STEAM) {
            assert cost = STATIC_COST_STEAM;
        }
        return get_operators_cost(operators_type_len - 1, operators_type + 1, sum + cost);
    }
}

struct InstructionSet {
    instructions_len: felt,
    instructions: felt*,
}

namespace ns_instruction_set {
    const W = 0;
    const A = 1;
    const S = 2;
    const D = 3;
    const Z = 4;
    const X = 5;
    const SKIP = 6;

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
}

struct Grid {
    x: felt,
    y: felt,
}

namespace ns_grid {
    const GRID_SIZE = 2;

    func diff{range_check_ptr}(a: Grid, b: Grid) -> (diff: Grid) {
        tempvar abs_x = abs_value(a.x - b.x);
        tempvar abs_y = abs_value(a.y - b.y);
        return (diff=Grid(abs_x, abs_y));
    }
}

struct MechState {
    id: felt,
    type: felt,
    status: felt,
    index: felt,
}

struct AtomState {
    id: felt,
    type: felt,
    status: felt,
    index: Grid,
    possessed_by: felt,
}

struct AtomFaucetState {
    id: felt,
    type: felt,
    status: felt,
    index: Grid,
}

namespace ns_atom_faucet_status {
    const ATOM_FAUCET_SIZE = 5;

    const FREE = 0;
    const CONSUMED = 1;

    func reset_faucets{syscall_ptr: felt*, range_check_ptr}(
        faucets_len: felt, faucets: felt*, new_faucets_len: felt, new_faucets: felt*
    ) {
        if (faucets_len == 0) {
            return ();
        }
        assert [new_faucets + new_faucets_len] = AtomFaucetState([faucets], [faucets + 1], FREE, Grid([faucets + 3], [faucets + 4]));
        reset_faucets(faucets_len - 1, faucets + 1, new_faucets_len + 1, new_faucets);
        return ();
    }
}

struct AtomSinkState {
    id: felt,
    index: Grid,
}

struct OperatorType {
    input_atoms_len: felt,
    input_atoms: felt*,
    ouput_atoms_len: felt,
    ouput_atoms: felt*,
}

struct Operator {
    input_len: felt,
    input: Grid*,
    input_atom_types: felt*,
    output_len: felt,
    output: Grid*,
    type: OperatorType,
}

namespace ns_operator {
    func verify_valid{range_check_ptr}(
        operators_type_len: felt,
        operators_type: felt*,
        operator_input: Grid*,
        operator_output: Grid*,
    ) {
        alloc_locals;
        if (operators_type_len == 0) {
            return ();
        }
        tempvar operator_type = [operators_type];
        let (input_offset, output_offset) = get_operator_lengths(operator_type);
        let (arr: felt*) = alloc();
        tempvar length_input = input_offset * ns_grid.GRID_SIZE;
        tempvar length_output = output_offset * ns_grid.GRID_SIZE;
        memcpy(arr, operator_input, length_input);
        memcpy(arr + length_input, operator_output, length_output);
        verify_valid_operator(input_offset + output_offset - 1, arr);

        return verify_valid(
            operators_type_len - 1,
            operators_type + 1,
            operator_input + length_input,
            operator_output + length_output,
        );
    }

    func verify_valid_operator{range_check_ptr}(len: felt, operator: felt*) {
        if (len == 0) {
            return ();
        }
        let grid_1 = Grid([operator], [operator + 1]);
        let grid_2 = Grid([operator + ns_grid.GRID_SIZE], [operator + ns_grid.GRID_SIZE + 1]);
        let (diff) = ns_grid.diff(grid_1, grid_2);
        tempvar sum = diff.x + diff.y;
        assert sum = 1;
        verify_valid_operator(len - 1, operator + ns_grid.GRID_SIZE);
        return ();
    }

    func get_operator_lengths{}(operator: felt) -> (input: felt, output: felt) {
        if (operator == ns_operator_type.STIR) {
            return (input=2, output=1);
        }
        if (operator == ns_operator_type.SHAKE) {
            return (input=2, output=1);
        }
        if (operator == ns_operator_type.STEAM) {
            return (input=3, output=2);
        }
        with_attr error_message("unknow operator") {
            assert 0 = 1;
        }
        return (input=0, output=0);
    }
}

struct BoardConfig {
    dimension: felt,
    atom_faucets_len: felt,
    atom_faucets: AtomFaucetState*,
    atom_sinks_len: felt,
    atom_sinks: AtomSinkState*,
    operators_len: felt,
    operators: Operator*,
}
