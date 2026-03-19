library ieee;
use ieee.std_logic_1164.all;

entity control_unit is
  port(
    opcode		: in std_logic_vector(6 downto 0);
    funct3		: in std_logic_vector(2 downto 0);
    funct7		: in std_logic_vector(6 downto 0);
    funct12		: in std_logic_vector(11 downto 0);

    RegWrite	: out std_logic;
    MemRead		: out std_logic;
    MemWrite	: out std_logic;
    ASel		: out std_logic;
    BSel		: out std_logic;
    ImmSel		: out std_logic_vector(2 downto 0);
    ALUCtrl		: out std_logic_vector(3 downto 0);
    WBSel		: out std_logic_vector(1 downto 0);
    BranchType	: out std_logic_vector(2 downto 0);
    JumpSel		: out std_logic_vector(1 downto 0);
    LoadType	: out std_logic_vector(2 downto 0);
    Halt		: out std_logic
  );
end entity control_unit;

architecture rtl of control_unit is
  -- Section 1: opcode/funct constants used by decode compares
  -- These are the fixed encodings from RV32I.
  constant OP_RTYPE	: std_logic_vector(6 downto 0) := "0110011";
  constant OP_ITYPE	: std_logic_vector(6 downto 0) := "0010011";
  constant OP_LOAD		: std_logic_vector(6 downto 0) := "0000011";
  constant OP_STORE	: std_logic_vector(6 downto 0) := "0100011";
  constant OP_BRANCH	: std_logic_vector(6 downto 0) := "1100011";
  constant OP_JAL		: std_logic_vector(6 downto 0) := "1101111";
  constant OP_JALR		: std_logic_vector(6 downto 0) := "1100111";
  constant OP_LUI		: std_logic_vector(6 downto 0) := "0110111";
  constant OP_AUIPC	: std_logic_vector(6 downto 0) := "0010111";
  constant OP_SYSTEM	: std_logic_vector(6 downto 0) := "1110011";

  -- funct7 patterns needed to split add/sub and srl/sra style pairs
  constant F7_0000000	: std_logic_vector(6 downto 0) := "0000000";
  constant F7_0100000	: std_logic_vector(6 downto 0) := "0100000";

  -- funct12 for WFI (0x105)
  constant F12_WFI		: std_logic_vector(11 downto 0) := "000100000101"; -- 0x105

  -- Section 2: top-level opcode group decode
  -- These signals identify broad instruction formats.
  signal op_rtype	: std_logic;
  signal op_itype	: std_logic;
  signal op_load	: std_logic;
  signal op_store	: std_logic;
  signal op_branch	: std_logic;
  signal op_jal		: std_logic;
  signal op_jalr	: std_logic;
  signal op_lui		: std_logic;
  signal op_auipc	: std_logic;
  signal op_system	: std_logic;

  -- Section 3: one-hot decode for each instruction row in the sheet
  -- R-type ALU instructions
  signal is_add		: std_logic;
  signal is_sub		: std_logic;
  signal is_and		: std_logic;
  signal is_xor		: std_logic;
  signal is_or		: std_logic;
  signal is_slt		: std_logic;
  signal is_sll		: std_logic;
  signal is_srl		: std_logic;
  signal is_sra		: std_logic;

  -- I-type ALU instructions
  signal is_addi	: std_logic;
  signal is_andi	: std_logic;
  signal is_xori	: std_logic;
  signal is_ori		: std_logic;
  signal is_slti	: std_logic;
  signal is_sltiu	: std_logic;
  signal is_slli	: std_logic;
  signal is_srli	: std_logic;
  signal is_srai	: std_logic;

  -- load/store instructions
  signal is_lb		: std_logic;
  signal is_lh		: std_logic;
  signal is_lw		: std_logic;
  signal is_lbu		: std_logic;
  signal is_lhu		: std_logic;
  signal is_sw		: std_logic;

  -- branch instructions
  signal is_beq		: std_logic;
  signal is_bne		: std_logic;
  signal is_blt		: std_logic;
  signal is_bge		: std_logic;
  signal is_bltu	: std_logic;
  signal is_bgeu	: std_logic;

  -- jump / upper-immediate / halt instructions
  signal is_jal		: std_logic;
  signal is_jalr	: std_logic;
  signal is_lui		: std_logic;
  signal is_auipc	: std_logic;
  signal is_wfi		: std_logic;

  -- Section 4: helper groups used by output equations
  signal is_any_r_alu	: std_logic;
  signal is_any_i_alu	: std_logic;
  signal is_any_load	: std_logic;
  signal is_any_branch	: std_logic;
begin
  -- Section 2 logic: opcode groups
  op_rtype <= '1' when opcode = OP_RTYPE else '0';
  op_itype <= '1' when opcode = OP_ITYPE else '0';
  op_load <= '1' when opcode = OP_LOAD else '0';
  op_store <= '1' when opcode = OP_STORE else '0';
  op_branch <= '1' when opcode = OP_BRANCH else '0';
  op_jal <= '1' when opcode = OP_JAL else '0';
  op_jalr <= '1' when opcode = OP_JALR else '0';
  op_lui <= '1' when opcode = OP_LUI else '0';
  op_auipc <= '1' when opcode = OP_AUIPC else '0';
  op_system <= '1' when opcode = OP_SYSTEM else '0';

  -- Section 3 logic: decode each supported instruction
  -- R-type decode
  is_add <= '1' when (op_rtype = '1' and funct3 = "000" and funct7 = F7_0000000) else '0';
  is_sub <= '1' when (op_rtype = '1' and funct3 = "000" and funct7 = F7_0100000) else '0';
  is_and <= '1' when (op_rtype = '1' and funct3 = "111" and funct7 = F7_0000000) else '0';
  is_xor <= '1' when (op_rtype = '1' and funct3 = "100" and funct7 = F7_0000000) else '0';
  is_or <= '1' when (op_rtype = '1' and funct3 = "110" and funct7 = F7_0000000) else '0';
  is_slt <= '1' when (op_rtype = '1' and funct3 = "010" and funct7 = F7_0000000) else '0';
  is_sll <= '1' when (op_rtype = '1' and funct3 = "001" and funct7 = F7_0000000) else '0';
  is_srl <= '1' when (op_rtype = '1' and funct3 = "101" and funct7 = F7_0000000) else '0';
  is_sra <= '1' when (op_rtype = '1' and funct3 = "101" and funct7 = F7_0100000) else '0';

  -- I-type ALU decode
  is_addi <= '1' when (op_itype = '1' and funct3 = "000") else '0';
  is_andi <= '1' when (op_itype = '1' and funct3 = "111") else '0';
  is_xori <= '1' when (op_itype = '1' and funct3 = "100") else '0';
  is_ori <= '1' when (op_itype = '1' and funct3 = "110") else '0';
  is_slti <= '1' when (op_itype = '1' and funct3 = "010") else '0';
  is_sltiu <= '1' when (op_itype = '1' and funct3 = "011") else '0';
  is_slli <= '1' when (op_itype = '1' and funct3 = "001" and funct7 = F7_0000000) else '0';
  is_srli <= '1' when (op_itype = '1' and funct3 = "101" and funct7 = F7_0000000) else '0';
  is_srai <= '1' when (op_itype = '1' and funct3 = "101" and funct7 = F7_0100000) else '0';

  -- load/store decode
  is_lb <= '1' when (op_load = '1' and funct3 = "000") else '0';
  is_lh <= '1' when (op_load = '1' and funct3 = "001") else '0';
  is_lw <= '1' when (op_load = '1' and funct3 = "010") else '0';
  is_lbu <= '1' when (op_load = '1' and funct3 = "100") else '0';
  is_lhu <= '1' when (op_load = '1' and funct3 = "101") else '0';
  is_sw <= '1' when (op_store = '1' and funct3 = "010") else '0';

  -- branch decode
  is_beq <= '1' when (op_branch = '1' and funct3 = "000") else '0';
  is_bne <= '1' when (op_branch = '1' and funct3 = "001") else '0';
  is_blt <= '1' when (op_branch = '1' and funct3 = "100") else '0';
  is_bge <= '1' when (op_branch = '1' and funct3 = "101") else '0';
  is_bltu <= '1' when (op_branch = '1' and funct3 = "110") else '0';
  is_bgeu <= '1' when (op_branch = '1' and funct3 = "111") else '0';

  -- jump/U-type/system decode
  is_jal <= op_jal;
  is_jalr <= '1' when (op_jalr = '1' and funct3 = "000") else '0';
  is_lui <= op_lui;
  is_auipc <= op_auipc;
  is_wfi <= '1' when (op_system = '1' and funct3 = "000" and funct12 = F12_WFI) else '0';

  -- Section 4 logic: grouped helper signals
  is_any_r_alu <= is_add or is_sub or is_and or is_xor or is_or or is_slt or is_sll or is_srl or is_sra;
  is_any_i_alu <= is_addi or is_andi or is_xori or is_ori or is_slti or is_sltiu or is_slli or is_srli or is_srai;
  is_any_load <= is_lb or is_lh or is_lw or is_lbu or is_lhu;
  is_any_branch <= is_beq or is_bne or is_blt or is_bge or is_bltu or is_bgeu;

  -- Section 5: final control outputs (bit equations)
  -- Each output bit is built from OR-combinations of one-hot instruction decodes.
  -- This keeps the logic combinational and close to a gate-level truth-table style.

  -- write enables
  RegWrite <= '1' when (is_any_r_alu = '1' or is_any_i_alu = '1' or is_any_load = '1' or is_jal = '1' or is_jalr = '1' or is_lui = '1' or is_auipc = '1') else '0';
  MemRead <= is_any_load;
  MemWrite <= is_sw;

  -- datapath operand select controls
  ASel <= '1' when (is_any_branch = '1' or is_jal = '1' or is_auipc = '1') else '0';
  BSel <= '1' when (is_any_i_alu = '1' or is_any_load = '1' or is_sw = '1' or is_any_branch = '1' or is_jal = '1' or is_jalr = '1' or is_lui = '1' or is_auipc = '1') else '0';

  -- ImmSel encoding from sheet:
  -- 000=R, 001=I, 010=S, 011=B, 100=U, 101=J
  ImmSel(2) <= is_lui or is_auipc or is_jal;
  ImmSel(1) <= is_sw or is_any_branch;
  ImmSel(0) <= is_jal or is_any_branch or is_any_i_alu or is_any_load or is_jalr;

  -- ALUCtrl encoding from sheet:
  -- 0000 ADD, 0001 SUB, 0010 AND, 0011 OR, 0100 XOR,
  -- 0101 SLT, 0110 SLTU, 0111 SLL, 1000 SRL, 1001 SRA, 1010 PASSB
  ALUCtrl(3) <= is_srl or is_srli or is_sra or is_srai or is_lui;
  ALUCtrl(2) <= is_xor or is_xori or is_slt or is_slti or is_sltiu or is_sll or is_slli;
  ALUCtrl(1) <= is_and or is_andi or is_or or is_ori or is_sltiu or is_sll or is_slli or is_lui;
  ALUCtrl(0) <= is_sub or is_or or is_ori or is_slt or is_slti or is_sll or is_slli or is_sra or is_srai;

  -- WBSel encoding from sheet:
  -- 00=ALU, 01=Mem, 10=PC+4
  WBSel(1) <= is_jal or is_jalr;
  WBSel(0) <= is_any_load;

  -- BranchType encoding from sheet:
  -- 000 none, 001 beq, 010 bne, 011 blt, 100 bge, 101 bltu, 110 bgeu
  BranchType(2) <= is_bge or is_bltu or is_bgeu;
  BranchType(1) <= is_bne or is_blt or is_bgeu;
  BranchType(0) <= is_beq or is_blt or is_bltu;

  -- JumpSel encoding from sheet:
  -- 00 none, 01 jal, 10 jalr
  JumpSel(1) <= is_jalr;
  JumpSel(0) <= is_jal;

  -- LoadType encoding from sheet:
  -- 000 none, 001 lb, 010 lh, 011 lw, 100 lbu, 101 lhu
  LoadType(2) <= is_lbu or is_lhu;
  LoadType(1) <= is_lh or is_lw;
  LoadType(0) <= is_lb or is_lw or is_lhu;

  -- halt output goes high only for decoded WFI
  Halt <= is_wfi;
end architecture rtl;
