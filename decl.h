enum i_type {add, addi, and, mult, madd, nor, or, ori, sll, sllv, sub, lui, sltu, slti, beq, bgez, bgtz, blez, bltz, lb, lw, sb, sw,nop,j,jal,jalr,jr,addu,mflo};

typedef struct{
	enum i_type itype; //type of ins
	int rs; //operand1
	int rt; //operand2
	int rd; // destination
	int rr;
	int isImm; //checks whether imm or not
	int isRt;  //writes back to Rt register
	int shamt; // specifies shift amount
	int imm; 
	char immT[33];
	char* ins_name;
	bool break_flag;
} instr;

typedef struct{
	int renable;
	int rPCSrc;				
	int rRegWrite; //RW 	
	int rALUSrc;   //ASrc 
	int rALUOp;				
	int rRegDst;   //Rsrc 
	int rbranch;			
	int rMemRead;  //MR   
	int rMemWrite; //MW   
	int rMemtoReg; //M2R  
	int rRs; //operand 1  
	int rRt; //destintion 
	int rRd; //operand2  
	int rALUResult;		 
	int rAddResult;	
	long long int rMultResult;	 
	int rReadAdd;		 
	int rWriteAdd;	
	int rCond;			
	int rReadData;
	long long int rReadMultData;
	int rWriteData;
	enum i_type ritype;
	int rimm;
	int risRt;
	int rrr;
	int rshamt;
	int rRsData;
	int rRtData;
	int rRrData;
	int rRdData;

	int wenable;
	int wPCSrc;
	int wRegWrite; //RW
	int wALUSrc;   //ASrc
	int wALUOp;
	int wRegDst;   //Rsrc
	int wbranch;
	int wMemRead;  //MR
	int wMemWrite; //MW
	int wMemtoReg; //M2R
	int wRs; //operand 1
	int wRt; //destintion
	int wRd; //operand2
	int wALUResult;
	int wAddResult;
	long long int wMultResult;
	long long int wReadMultData;
	int wReadAdd;
	int wWriteAdd;
	int wCond;
	int wReadData; 
	int wWriteData;
	enum i_type witype;
	int wimm;
	int wisRt;
	int wrr;
	int wshamt;
	int wRsData;
	int wRtData;
	int wRrData;
	int wRdData;
} regs;

void yyerror(char *);
int bin_to_reg(char* str, int idx);
int imm_to_reg(char* str);
int b_imm_to_reg(char* str);
void* fetch_ins(void* instruction_data);
void* decode_ins(void* instruction_data);
void* ex_ins(void* instruction_data);
void* mem_ins(void* instruction_data);
void* write_back_ins(void* instruction_data);
char *strlwr(char *str);
