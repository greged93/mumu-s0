%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

from contracts.constants import Grid, ns_grid, ns_operators, ns_atoms

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

func verify_valid{range_check_ptr}(
    operators_type_len: felt, operators_type: felt*, operator_input: Grid*, operator_output: Grid*
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
    if (operator == ns_operators.STIR) {
        return (input=2, output=1);
    }
    if (operator == ns_operators.SHAKE) {
        return (input=2, output=1);
    }
    if (operator == ns_operators.STEAM) {
        return (input=3, output=2);
    }
    with_attr error_message("unknow operator") {
        assert 0 = 1;
    }
    return (input=0, output=0);
}

func get_operators_cost{range_check_ptr}(
    operators_type_len: felt, operators_type: felt*, sum: felt
) -> felt {
    if (operators_type_len == 0) {
        return sum;
    }
    tempvar cost;
    tempvar operator_type = [operators_type];
    if (operator_type == ns_operators.STIR) {
        assert cost = ns_operators.STATIC_COST_STIR;
    }
    if (operator_type == ns_operators.SHAKE) {
        assert cost = ns_operators.STATIC_COST_SHAKE;
    }
    if (operator_type == ns_operators.STEAM) {
        assert cost = ns_operators.STATIC_COST_STEAM;
    }
    return get_operators_cost(operators_type_len - 1, operators_type + 1, sum + cost);
}

func stir{}() -> (stir: OperatorType) {
    let (input_atoms: felt*) = alloc();
    assert input_atoms[0] = ns_atoms.VANILLA;
    assert input_atoms[1] = ns_atoms.VANILLA;
    let (output_atoms: felt*) = alloc();
    assert output_atoms[0] = ns_atoms.HAZELNUT;

    let stir = OperatorType(
        input_atoms_len=2, input_atoms=input_atoms, output_atoms_len=1, output_atoms=output_atoms
    );
    return (stir=stir);
}

func shake{}() -> (stir: OperatorType) {
    let (input_atoms: felt*) = alloc();
    assert input_atoms[0] = ns_atoms.HAZELNUT;
    assert input_atoms[1] = ns_atoms.HAZELNUT;
    let (output_atoms: felt*) = alloc();
    assert output_atoms[0] = ns_atoms.CHOCOLATE;

    let stir = OperatorType(
        input_atoms_len=2, input_atoms=input_atoms, output_atoms_len=1, output_atoms=output_atoms
    );
    return (stir=stir);
}

func steam{}() -> (stir: OperatorType) {
    let (input_atoms: felt*) = alloc();
    assert input_atoms[0] = ns_atoms.HAZELNUT;
    assert input_atoms[1] = ns_atoms.CHOCOLATE;
    assert input_atoms[2] = ns_atoms.CHOCOLATE;
    let (output_atoms: felt*) = alloc();
    assert output_atoms[0] = ns_atoms.TRUFFLE;
    assert output_atoms[1] = ns_atoms.VANILLA;

    let stir = OperatorType(
        input_atoms_len=3, input_atoms=input_atoms, output_atoms_len=2, output_atoms=output_atoms
    );
    return (stir=stir);
}
