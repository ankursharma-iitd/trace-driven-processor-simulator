%option noyywrap

%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
#include <unistd.h>
#include <stdbool.h>
#include "decl.h"
#include "cache.h"
#include "main.h"

int memory[16777216] = {0};
int registers[35] = {0};
instr instructions[1000];
int nInstr=0;
int nIexe=0;
int nIcache=0;
int nDcache=0;
int nCycle=0;
int nIdle=0;
int rpc = 0;
int wpc = 0;
int r_pc=0;
int w_pc=0;


int iParams = 1;
int latency = 0;
float frequency = 2.0;

regs if_id, id_ex, ex_mem, mem_wb;
FILE* trace;

%}

%%

"# Common config file for MIPs core" 		{}
"[perf_model/core]"			{}
"[perf_model/dram]"			{}
"\n"						{}		

"[perf_model/l1_icache]" 				{iParams = 1;}
"[perf_model/l1_dcache]" 				{iParams = 0;}
"[perf_model/l1_ucache]" 				{iParams = 2;}

"perfect = false"							{}
"cache_size = "[0-9]+		{
								int value = atoi(yytext + 13);
								// printf("%d\n",value );
								if(iParams == 0){
									set_cache_param(CACHE_PARAM_DSIZE, value * 1024);
								}	
								if(iParams == 1){
									set_cache_param(CACHE_PARAM_ISIZE, value * 1024);
								}
								if(iParams == 2){
									set_cache_param(CACHE_PARAM_USIZE, value * 1024);
								}
							}


"associativity = "(0|1)		{
								int value = atoi(yytext + 16);
								// printf("%d\n",value );
								set_cache_param(CACHE_PARAM_ASSOC, value);
							}

"replacement_policy = lru"	{}
"writethrough = "(0|1)		{
								int value = atoi(yytext + 15);
								// printf("%d\n",value );
								set_cache_param(CACHE_PARAM_WRITETHROUGH, value);
							}

"block_size = "[0-9]+		{
								int value = atoi(yytext + 13);
								// printf("%d\n",value );
								set_cache_param(CACHE_PARAM_BLOCK_SIZE, value);
							}

"frequency = "[0-9]+("."[0-9]+)? 	{frequency = atof(yytext + 12);}
"latency = "[0-9]+ 					{latency = atoi(yytext + 10);
										// printf("%d\n",latency );
									}



[0-9 a-f A-F]{8} 	{
					// printf("Instruction: %s\n", yytext);
					// exit(1);
					int i;
					// char instruction[33] = "";
					char* instruction = calloc(33,sizeof(char))	;
					strcpy(instruction,"");
					for(i=0;i<8;i++){
						switch(yytext[i]){
							case '0': strcat(instruction,"0000"); break;
				            case '1': strcat(instruction,"0001"); break;
				            case '2': strcat(instruction,"0010"); break;
				            case '3': strcat(instruction,"0011"); break;
				            case '4': strcat(instruction,"0100"); break;
				            case '5': strcat(instruction,"0101"); break;
				            case '6': strcat(instruction,"0110"); break;
				            case '7': strcat(instruction,"0111"); break;
				            case '8': strcat(instruction,"1000"); break;
				            case '9': strcat(instruction,"1001"); break;
				            case 'A': strcat(instruction,"1010"); break;
				            case 'B': strcat(instruction,"1011"); break;
				            case 'C': strcat(instruction,"1100"); break;
				            case 'D': strcat(instruction,"1101"); break;
				            case 'E': strcat(instruction,"1110"); break;
				            case 'F': strcat(instruction,"1111"); break;
				            case 'a': strcat(instruction,"1010"); break;
				            case 'b': strcat(instruction,"1011"); break;
				            case 'c': strcat(instruction,"1100"); break;
				            case 'd': strcat(instruction,"1101"); break;
				            case 'e': strcat(instruction,"1110"); break;
				            case 'f': strcat(instruction,"1111"); break;

						}
					}
					// printf("Instruction: %s\n", instruction );
					instructions[nInstr].isImm = 0;
					instructions[nInstr].isRt = 0;
					instructions[nInstr].break_flag = false;
					int isValid = 0;

					instructions[nInstr].ins_name=(char*)malloc(100*sizeof(char));
					strcpy(instructions[nInstr].ins_name,yytext);
					if((strncmp(instruction,"000000",6) == 0) &&(strncmp(instruction + 21,"00000",5) == 0) && (strncmp(instruction + 26,"100000",6) == 0) ) { //add
						instructions[nInstr].itype = add;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].rd = bin_to_reg(instruction,16);
						isValid = 1;
					}

					if((strncmp(instruction,"000000",6) == 0) &&(strncmp(instruction + 21,"00000",5) == 0) && (strncmp(instruction + 26,"100001",6) == 0) ) { //addu
						instructions[nInstr].itype = addu;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].rd = bin_to_reg(instruction,16);
						isValid = 1;
					}

					if((strncmp(instruction,"001000",6) == 0)) { //addi
						instructions[nInstr].itype = addi;
						instructions[nInstr].isImm = 1;
						instructions[nInstr].isRt = 1;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						// instructions[nInstr].imm = imm_to_reg(instruction);
						if(instruction[16]=='0'){
							strcpy(instructions[nInstr].immT,"0000000000000000");
						} else{
							strcpy(instructions[nInstr].immT,"1111111111111111");
						}
						strcat(instructions[nInstr].immT,instruction + 16);
						instructions[nInstr].imm = bimm_to_reg(instructions[nInstr].immT);
						isValid = 1;
					}
					if((strncmp(instruction,"000000",6) == 0) &&(strncmp(instruction + 21,"00000",5) == 0) && (strncmp(instruction + 26,"100100",6) == 0) ) {
						instructions[nInstr].itype = and;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].rd = bin_to_reg(instruction,16);
						isValid = 1;
					}
					if((strncmp(instruction,"000000",6) == 0) &&(strncmp(instruction + 16,"0000000000",10) == 0) && (strncmp(instruction + 26,"011000",6) == 0) ) {
						instructions[nInstr].itype = mult;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						isValid = 1;
					}

					if((strncmp(instruction,"011100",6) == 0) && (strncmp(instruction + 16,"0000000000000000",16) == 0)){
						instructions[nInstr].itype = madd;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						isValid = 1;
					}

					if((strncmp(instruction,"000000",6) == 0) &&(strncmp(instruction + 21,"00000",5) == 0) && (strncmp(instruction + 26,"100111",6) == 0) ) {
						instructions[nInstr].itype = nor;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].rd = bin_to_reg(instruction,16);
						isValid = 1;
					}
					if((strncmp(instruction,"000000",6) == 0) &&(strncmp(instruction + 21,"00000",5) == 0) && (strncmp(instruction + 26,"100101",6) == 0) ) {
						instructions[nInstr].itype = or;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].rd = bin_to_reg(instruction,16);
						isValid = 1;
					}

					if((strncmp(instruction,"000010",6) == 0) ){ //jump instruction
						// printf("SEEEEEEEEEEEEEEEEE THISSSSSSSSSSSSSSSS -> Busted j\n");
						instructions[nInstr].itype = j;
						instructions[nInstr].isImm = 1;
						if(instruction[6]=='0'){
							strcpy(instructions[nInstr].immT,"000000");
						} else{
							strcpy(instructions[nInstr].immT,"111111");
						}
						strcat(instructions[nInstr].immT,instruction + 6);
						instructions[nInstr].imm = b_imm_to_reg(instructions[nInstr].immT);
						isValid = 1;
					}

					if((strncmp(instruction,"000011",6) == 0) ){ //jump and link instruction
						// printf("SEEEEEEEEEEEEEEEEE THISSSSSSSSSSSSSSSS -> Busted jal\n");
						instructions[nInstr].itype = jal;
						instructions[nInstr].isImm = 1;
						if(instruction[6]=='0'){
							strcpy(instructions[nInstr].immT,"000000");
						} else{
							strcpy(instructions[nInstr].immT,"111111");
						}
						strcat(instructions[nInstr].immT,instruction + 6);
						instructions[nInstr].imm = b_imm_to_reg(instructions[nInstr].immT);
						isValid = 1;
					}

					if((strncmp(instruction,"000000",6) == 0) && (strncmp(instruction+11,"00000",5) == 0) && (strncmp(instruction,"00000",21) == 0) &&(strncmp(instruction+26,"001001",6) == 0))
					{ //jalr instruction
						// printf("SEEEEEEEEEEEEEEEEE THISSSSSSSSSSSSSSSS -> Busted jalr\n");
						instructions[nInstr].itype = jalr;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rd = bin_to_reg(instruction,11);
						isValid = 1;
					}



					if((strncmp(instruction,"000000",6) == 0) && (strncmp(instruction+11,"000000000000000",15) == 0) &&(strncmp(instruction+26,"001000",6) == 0))
					{ //jr instruction
						// printf("SEEEEEEEEEEEEEEEEE THISSSSSSSSSSSSSSSS -> Busted jr\n");
						instructions[nInstr].itype = jr;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						isValid = 1;
					}		

					if((strncmp(instruction,"00000000000000000",16) == 0) && (strncmp(instruction+21,"00000010010",11) == 0)){
						printf("SEEEEEEEEEEEEEEEEE THISSSSSSSSSSSSSSSS -> Busted mflo\n");
						// instructions[nInstr].itype = mflo;
						instructions[nInstr].rd = bin_to_reg(instruction,16);
						isValid = 1;
						// printf("WHOOOOOOOOOOOOOOOOOOOOOOOOOOOOOAAAAAAAAAAAAAAAAAAAAAAAAAA %d\n",instructions[nInstr].rd);						
					} //mflo

					if((strncmp(instruction,"001101",6) == 0)) { 
						instructions[nInstr].itype = ori;
						instructions[nInstr].isImm = 1;
						instructions[nInstr].isRt = 1;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						if(instruction[16]=='0'){
							strcpy(instructions[nInstr].immT,"0000000000000000");
						} else{
							strcpy(instructions[nInstr].immT,"1111111111111111");
						}
						strcat(instructions[nInstr].immT,instruction + 16);
						instructions[nInstr].imm = bimm_to_reg(instructions[nInstr].immT);
						// printf("HEREEEEEEEEEEEE %d\n", instructions[nInstr].imm);
						isValid = 1;
					}
					if((strncmp(instruction,"000000",6) == 0) && (strncmp(instruction + 26,"000000",6) == 0) ) {
						instructions[nInstr].itype = sll;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].rd = bin_to_reg(instruction,16);
						instructions[nInstr].shamt = bin_to_reg(instruction,21);
						isValid = 1;
					}
					if((strncmp(instruction,"000000",6) == 0) &&(strncmp(instruction + 21,"00000",5) == 0) && (strncmp(instruction + 26,"000100",6) == 0) ) {
						instructions[nInstr].itype = sllv;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].rd = bin_to_reg(instruction,16);
						isValid = 1;
					}
					if((strncmp(instruction,"000000",6) == 0) &&(strncmp(instruction + 21,"00000",5) == 0) && (strncmp(instruction + 26,"100010",6) == 0) ) {
						instructions[nInstr].itype = sub;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].rd = bin_to_reg(instruction,16);
						isValid = 1;
					}
					if((strncmp(instruction,"001111",6) == 0) &&(strncmp(instruction + 6,"00000",5) == 0)) { 
						instructions[nInstr].itype = lui;
						instructions[nInstr].isImm = 1;
						instructions[nInstr].isRt = 1;
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].imm = imm_to_reg(instruction);
						isValid = 1;
					}
					if((strncmp(instruction,"000000",6) == 0) &&(strncmp(instruction + 21,"00000",5) == 0) && (strncmp(instruction + 26,"101011",6) == 0) ) {
						instructions[nInstr].itype = sltu;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].rd = bin_to_reg(instruction,16);
						isValid = 1;
					}
					if((strncmp(instruction,"001010",6) == 0)) { //?????????????????????????????
						instructions[nInstr].itype = slti;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rd = bin_to_reg(instruction,11);
						instructions[nInstr].isImm = 1;
						// instructions[nInstr].imm = imm_to_reg(instruction);
						if(instruction[16]=='0'){
							strcpy(instructions[nInstr].immT,"0000000000000000");
						} else{
							strcpy(instructions[nInstr].immT,"1111111111111111");
						}
						strcat(instructions[nInstr].immT,instruction + 16);
						instructions[nInstr].imm = bimm_to_reg(instructions[nInstr].immT);
						isValid = 1;
					}
					if((strncmp(instruction,"000100",6) == 0)) { 
						instructions[nInstr].itype = beq;
						instructions[nInstr].isImm = 1;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						if(instruction[16]=='0'){
							strcpy(instructions[nInstr].immT,"0000000000000000");
						} else{
							strcpy(instructions[nInstr].immT,"1111111111111111");
						}
						strcat(instructions[nInstr].immT,instruction + 16);
						instructions[nInstr].imm = b_imm_to_reg(instructions[nInstr].immT);
						isValid = 1;
					}
					if((strncmp(instruction,"000001",6) == 0) && (strncmp(instruction + 11,"00001",5) == 0)) { 
						instructions[nInstr].itype = bgez;
						instructions[nInstr].isImm = 1;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						if(instruction[16]=='0'){
							strcpy(instructions[nInstr].immT,"0000000000000000");
						} else{
							strcpy(instructions[nInstr].immT,"1111111111111111");
						}
						strcat(instructions[nInstr].immT,instruction + 16);
						instructions[nInstr].imm = b_imm_to_reg(instructions[nInstr].immT);
						isValid = 1;
					}
					if((strncmp(instruction,"000111",6) == 0) && (strncmp(instruction + 11,"00000",5) == 0)) { 
						instructions[nInstr].itype = bgtz;
						instructions[nInstr].isImm = 1;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						if(instruction[16]=='0'){
							strcpy(instructions[nInstr].immT,"0000000000000000");
						} else{
							strcpy(instructions[nInstr].immT,"1111111111111111");
						}
						strcat(instructions[nInstr].immT,instruction + 16);
						instructions[nInstr].imm = b_imm_to_reg(instructions[nInstr].immT);
						isValid = 1;
					}
					if((strncmp(instruction,"000110",6) == 0) && (strncmp(instruction + 11,"00000",5) == 0)) { 
						instructions[nInstr].itype = blez;
						instructions[nInstr].isImm = 1;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						if(instruction[16]=='0'){
							strcpy(instructions[nInstr].immT,"0000000000000000");
						} else{
							strcpy(instructions[nInstr].immT,"1111111111111111");
						}
						strcat(instructions[nInstr].immT,instruction + 16);
						instructions[nInstr].imm = b_imm_to_reg(instructions[nInstr].immT);
						isValid = 1;
					}
					if((strncmp(instruction,"000001",6) == 0) && (strncmp(instruction + 11,"00000",5) == 0)) { 
						instructions[nInstr].itype = bltz;
						instructions[nInstr].isImm = 1;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						if(instruction[16]=='0'){
							strcpy(instructions[nInstr].immT,"0000000000000000");
						} else{
							strcpy(instructions[nInstr].immT,"1111111111111111");
						}
						strcat(instructions[nInstr].immT,instruction + 16);
						instructions[nInstr].imm = b_imm_to_reg(instructions[nInstr].immT);
						isValid = 1;
					}
					if((strncmp(instruction,"100000",6) == 0)) { 
						instructions[nInstr].itype = lb;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].isImm = 1;
						instructions[nInstr].isRt = 1;
						instructions[nInstr].imm = imm_to_reg(instruction);
						isValid = 1;
					}
					if((strncmp(instruction,"100011",6) == 0)) { 
						instructions[nInstr].itype = lw;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].imm = imm_to_reg(instruction);
						instructions[nInstr].isImm = 1;
						instructions[nInstr].isRt = 1;
						isValid = 1;
					}
					if((strncmp(instruction,"101000",6) == 0)) { 
						instructions[nInstr].itype = sb;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].imm = imm_to_reg(instruction);
						instructions[nInstr].isImm = 1;
						isValid = 1;
					}
					if((strncmp(instruction,"101011",6) == 0)) { 
						instructions[nInstr].itype = sw;
						instructions[nInstr].rs = bin_to_reg(instruction,6);
						instructions[nInstr].rt = bin_to_reg(instruction,11);
						instructions[nInstr].imm = imm_to_reg(instruction);
						instructions[nInstr].isImm = 1;
						isValid = 1;
					}

					if(!isValid) {
						yyerror("Invalid instruction.");
					} else {nInstr++;}
				}


%%

void yyerror(char* s){
	printf("%s\n", s);
	// exit(1);
}

int bin_to_reg(char* str,int idx){
	int i;
	int res = 0;
	for(i=0;i<5;i++){
		res = res*2 + str[idx + i] - 48;
	}
	// printf("%d\n",res );
	return res;
}

int imm_to_reg(char* str){
	int i;
	int res = 0;
	for(i=0;i<16;i++){
		res = res*2 + str[i+16] - 48;
	}
	// printf("%d\n",res );
	if(str[16] == '1'){
		res = 65536 - res;
		res = -1*res;
	}
	return res;
}

int b_imm_to_reg(char* str){
	int i;
	int res = 0;
	for(i=0;i<32;i++){
		res = res*2 + str[i] - 48;
	}
	// printf("%d\n",res );
	if(str[0] == '1'){
		res = 4294967296 - res;
		res = -1*res;
	}
	res = res << 2;
	return res;
}

int bimm_to_reg(char* str){
	int i;
	int res = 0;
	for(i=0;i<32;i++){
		res = res*2 + str[i] - 48;
	}
	// printf("%d\n",res );
	if(str[0] == '1'){
		res = 4294967296 - res;
		res = -1*res;
	}
	return res;
}

int bin_to_int(char* str){
	int i;
	int res = 0;
	for(i=0;i<32;i++){
		res = res*2 + str[i] - 48;
	}
	return res;	
}

void* fetch_ins(void* instruction_data){
	instr* my_instruction;
	my_instruction = (instr *) instruction_data;
	//Fetch instruction
	
	// printf("IFtype: %d\n", my_instruction->itype);
	// printf("IFrs: %d\n", my_instruction->rs);
	// printf("IFrt: %d\n", my_instruction->rt);
	// printf("IFrd: %d\n", my_instruction->rd);
	if_id.wenable = 1;

	if(((if_id.ritype == lw)||(if_id.ritype == lb))&&((my_instruction->rs == if_id.rRt)||(my_instruction->rt == if_id.rRt))){
		if_id.witype = nop;
		nIdle++;
		nIexe--;
		pthread_exit(NULL);
	}

	wpc++;
	w_pc=wpc;
	if_id.wRs    = my_instruction->rs;
	if_id.wRt    = my_instruction->rt;
	if_id.wRd    = my_instruction->rd;
	if_id.wrr    = my_instruction->rr;
	if_id.wimm   = my_instruction->imm;
	if_id.wshamt = my_instruction->shamt;
	if_id.witype = my_instruction->itype;
	if_id.wisRt  = my_instruction->isRt;

	fprintf(trace, "%d %x\n", 2, rpc*4 + 4194304);
	// printf("fetch_ins\n");
}

void* decode_ins(void* instruction_data){
	instr* my_instruction;
	my_instruction = (instr *) instruction_data;
	//TODO
	
	id_ex.wenable = if_id.renable;
	// if(if_id.renable == 0){
	// 	// if_id.wenable = 1;
	// 	id_ex.witype = 23;
	// 	pthread_exit(NULL);
	// }

	// printf("id type: %d\n",if_id.ritype );
	// printf("id read: %d\n\n",if_id.rMemRead );
	// printf("IDtype: %d\n", if_id.ritype);
	// printf("IDrs: %d\n"  , if_id.rRs);
	// printf("IDrt: %d\n"  , if_id.rRt);
	// printf("IDrd: %d\n\n", if_id.rRd);
	// printf("id type: %d\n",if_id.itype );
	// printf("id type: %d\n",if_id.itype );

	id_ex.wRs = if_id.rRs;
	id_ex.wRt = if_id.rRt;
	id_ex.wRd = if_id.rRd;
	id_ex.wrr    = if_id.rrr;
	id_ex.wimm   = if_id.rimm;
	id_ex.wshamt = if_id.rshamt;
	id_ex.witype = if_id.ritype;
	id_ex.wisRt  = if_id.risRt;

	// id_ex.wWriteData = registers[if_id.rRt];
	// id_ex.wRsData = registers[if_id.rRs];
	// id_ex.wRtData = registers[if_id.rRt];
	// id_ex.wRrData = registers[if_id.rrr];
	// id_ex.wRdData = registers[if_id.rRd];

	// printf(".........%d\n", id_ex.wWriteData);
	// printf(".........%d\n", id_ex.wRsData);
	// printf(".........%d\n", id_ex.wRtData);
	// printf(".........%d\n", id_ex.wRrData);
	// printf(".........%d\n", id_ex.wRdData);

	id_ex.wPCSrc = 0;
	id_ex.wRegWrite =1;
	id_ex.wALUSrc =0;
	id_ex.wbranch =0;
	id_ex.wRegDst =1;
	id_ex.wMemRead =0;
	id_ex.wMemWrite =0;
	id_ex.wMemtoReg =0;
	id_ex.wALUResult = registers[if_id.rRt];
	// id_ex.wALUOp =0;    ALU!!!
	
	switch(if_id.ritype) {
		case 0:
			
			break;	
		case 1:
			id_ex.wRegDst =0;
			break;	
		case 2:
			
			break;	
		case 3: //mult
			
			break;	
		case 4:
			//madd
			
			break;	
		case 5:
			//nor
			
			break;	
		case 6:
			//or
			
			break;	
		case ori:
			id_ex.wRegDst =0;
			break;	
		case 8:
			
			break;	
		case 9:
			
			break;	
		case 10:
			break;	
		case 11:
			id_ex.wRegDst =0;
			break;	
		case 12:
			break;	
		case 13:
			break;	
		case 14:
			id_ex.wRegWrite =0;
			id_ex.wbranch =1;
			break;	
		case 15:
			id_ex.wRegWrite =0;
			id_ex.wbranch =1;
			break;	
		case 16:
			id_ex.wRegWrite =0;
			id_ex.wbranch =1;
			break;	
		case 17:
			id_ex.wRegWrite =0;
			id_ex.wbranch =1;
			break;	
		case 18:
			id_ex.wRegWrite =0;
			id_ex.wbranch =1;
			break;	
		case 19:
			id_ex.wRegDst =0;
			id_ex.wALUSrc =1;
			id_ex.wMemRead =1;
			id_ex.wMemtoReg =0;
			break;	
		case 20:
			id_ex.wRegDst =0;
			id_ex.wALUSrc =1;
			id_ex.wMemRead =1;
			id_ex.wMemtoReg =0;
			break;	
		case 21:
			id_ex.wRegWrite =0;
			id_ex.wALUSrc =1;
			id_ex.wMemWrite =1;
			break;	
		case 22:
			id_ex.wRegWrite =0;
			id_ex.wALUSrc =1;
			id_ex.wMemWrite =1;
			break;	
		case 23: 
			id_ex.wPCSrc = 0;
			id_ex.wRegWrite =0;
			id_ex.wALUSrc =0;
			id_ex.wbranch =0;
			id_ex.wRegDst =0;
			id_ex.wMemRead =0;
			id_ex.wMemWrite =0;
			id_ex.wMemtoReg =0;
			break;
	}
	// printf("decode_ins\n");
}

void* ex_ins(void* instruction_data){
	instr* my_instruction;
	my_instruction = (instr *) instruction_data;
	//TODO
	
	// ex_mem.wenable = id_ex.renable;
	// if(id_ex.renable == 0){
	// 	// id_ex.wenable = 1;
	// 	pthread_exit(NULL);
	// }

	ex_mem.wRs    = id_ex.rRs;
	ex_mem.wRt    = id_ex.rRt;
	ex_mem.wRd    = id_ex.rRd;
	ex_mem.wrr    = id_ex.rrr;
	ex_mem.wimm   = id_ex.rimm;
	ex_mem.wshamt = id_ex.rshamt;
	ex_mem.witype = id_ex.ritype;
	ex_mem.wisRt  = id_ex.risRt;

	ex_mem.wRegWrite = id_ex.rRegWrite;
	ex_mem.wALUSrc   = id_ex.rALUSrc;
	ex_mem.wbranch   = id_ex.rbranch;
	ex_mem.wRegDst   = id_ex.rRegDst;
	ex_mem.wMemRead  = id_ex.rMemRead;
	ex_mem.wMemWrite = id_ex.rMemWrite;
	ex_mem.wMemtoReg = id_ex.rMemtoReg;
	// ex_mem.wWriteData= registers[id_ex.rRt];
	// ex_mem.wWriteData= id_ex.rWriteData;
	ex_mem.wRsData= registers[id_ex.rRs];
	ex_mem.wRtData= registers[id_ex.rRt];
	ex_mem.wRrData= registers[id_ex.rrr];
	ex_mem.wRdData= registers[id_ex.rRd];

	// ex_mem.wRsData= id_ex.rRsData;
	// ex_mem.wRtData= id_ex.rRtData;
	// ex_mem.wRrData= id_ex.rRrData;
	// ex_mem.wRdData= id_ex.rRdData;
	ex_mem.wCond = 0;

	// printf("ex: +++++%d %d\n", id_ex.ritype, my_instruction->itype);
	// printf("ex: +++++%d %d\n", id_ex.rRs, my_instruction->rs);
	// printf("ex: +++++%d %d\n", id_ex.rRt, my_instruction->rt);
	// printf("ex: +++++%d %d\n", id_ex.rRd, my_instruction->rd);
	// printf("ex: +++++%d %d\n\n", id_ex.rimm, my_instruction->imm);

	// printf("EXtype: %d\n", id_ex.ritype);
	// printf("EXrs: %d\n"  , id_ex.rRs);
	// printf("EXrt: %d\n"  , id_ex.rRt);
	// printf("EXrd: %d\n\n", id_ex.rRd);

	int op1,op2;

	// printf("#####%d\n", mem_wb.rRegWrite);
	// printf("#####%d\n", ex_mem.rRd);
	// printf("#####%d\n", id_ex.rRs);
	// printf("#####%d\n", ex_mem.ritype);
	// printf("#####%d\n", ex_mem.rRt);
	// printf("#####%d\n", id_ex.rRs);
	// printf("#####%d\n", mem_wb.ritype);
	// printf("#####%d\n", mem_wb.rRt);
	// printf("#####%d\n", id_ex.rRs);
	// printf("#####%d\n", ex_mem.rRegWrite);


	if((ex_mem.rRegWrite == 1) && (id_ex.ritype != 11) && (ex_mem.ritype != nop) && (((ex_mem.risRt == 1) && (ex_mem.rRt == id_ex.rRs)) || ((ex_mem.risRt == 0) && (ex_mem.rRd == id_ex.rRs))) ){
		op1 = ex_mem.rALUResult;
		// printf("                            fwdA1\n");
	}
	else {
		// if((mem_wb.rRegWrite == 1) && ((ex_mem.rRd != id_ex.rRs)||(((ex_mem.ritype == 1)||(ex_mem.ritype == 7)||(ex_mem.ritype == 11))&& (ex_mem.rRt != id_ex.rRs))) && ((mem_wb.rRd == id_ex.rRs)||(((mem_wb.ritype == 1)||(mem_wb.ritype == 7)||(mem_wb.ritype == 11)||(ex_mem.ritype == 19)||(ex_mem.ritype == 20))&& (mem_wb.rRt == id_ex.rRs)))&& (id_ex.ritype != 11)){
		// 	printf("                        fwdA2\n");
		// 	op1 = mem_wb.rALUResult;
		// }

		if((mem_wb.rRegWrite == 1) && (id_ex.ritype != 11) && (id_ex.ritype != nop) && ((ex_mem.ritype == 23) || ((ex_mem.risRt == 1) && (ex_mem.rRt != id_ex.rRs)) || ((ex_mem.risRt == 0) && (ex_mem.rRd != id_ex.rRs))) && (((mem_wb.risRt == 1) && (mem_wb.rRt == id_ex.rRs)) || ((mem_wb.risRt == 0) && (mem_wb.rRd == id_ex.rRs))) ){
			op1 = mem_wb.rReadData;
			// printf("                            fwdA2\n");
		}

		else{
			op1=ex_mem.wRsData; 
		}
		
	}//for source 1 of ALU

	if((ex_mem.rRegWrite == 1) && (id_ex.ritype != 11) && (ex_mem.ritype != nop) && (((ex_mem.risRt == 1) && (ex_mem.rRt == id_ex.rRt)) || ((ex_mem.risRt == 0) && (ex_mem.rRd == id_ex.rRt))) ){
		op2 = ex_mem.rALUResult;
	}
	else{ 
		// if((mem_wb.rRegWrite == 1) && ((ex_mem.rRd != id_ex.rRt)||(((ex_mem.ritype == 1)||(ex_mem.ritype == 7)||(ex_mem.ritype == 11))&& (ex_mem.rRt != id_ex.rRt))) && ((mem_wb.rRd == id_ex.rRt)||(((mem_wb.ritype == 1)||(mem_wb.ritype == 7)||(mem_wb.ritype == 11)||(ex_mem.ritype == 19)||(ex_mem.ritype == 20))&& (mem_wb.rRt == id_ex.rRt)))&& (id_ex.ritype != 11)){
		// 	printf("                                 fwdB2\n");
		// 	op2 = mem_wb.rReadData;
		// }
		if((mem_wb.rRegWrite == 1) && (id_ex.ritype != 11) && (id_ex.ritype != nop) && ((ex_mem.ritype == 23) || ((ex_mem.risRt == 1) && (ex_mem.rRt != id_ex.rRt)) || ((ex_mem.risRt == 0) && (ex_mem.rRd != id_ex.rRt))) && (((mem_wb.risRt == 1) && (mem_wb.rRt == id_ex.rRt)) || ((mem_wb.risRt == 0) && (mem_wb.rRd == id_ex.rRt))) ){
			op2 = mem_wb.rReadData;
			// printf("                            fwdB2\n");
		}
		else 
		{
			op2=ex_mem.wRtData;
		} //for source 2 of ALU
	}
	int imm=id_ex.rimm; //get imm field
	int des=ex_mem.wRdData; 
	int mla=ex_mem.wRrData; 
	int shamt=id_ex.rshamt; //shift amount
	int result=id_ex.rALUResult; //for ALU calcualtions of DP instructions
	long long int mult_result = id_ex.rMultResult;
	int z;
	int result_address =0; //for target_address ALU calculations
	int read_address=0; //gives the reading address
	int write_address=0; //gives the writing address
	long long int x = registers[32];
	x = x << 32;
	long long int y = registers[33];

	// printf("!!!!!!!!!!!!!!!!!!!!%d\n", op1);
	// printf("!!!!!!!!!!!!!!!!!!!!%d\n", op2);

	switch(id_ex.ritype)
	{
		case 0:
			result = op1 + op2; //store in rd
			break;	
		case 1:
			result = op1 + imm; //store in rt
			break;	
		case 2:
			result = op1 & op2; //store in rd
			break;	
		case 3:
			//mult
			mult_result = op1 * op2; //store in lO
			break;	
		case 4:
			//madd
			mult_result = op1 * op2 + (x|y); //store in rd
			break;	
		case 5:
			//nor
			result = ~ ( op1 | op2); //store in rd
			break;	
		case 6:
			//or
			result = ( op1 | op2); //store in rd
			break;	
		case 7:
			result = ( op1 | imm); //store in rt
			// printf("yay1 %d\n",result );
			// printf("yay1 %d\n",op1 );
			// printf("yay1 %d\n",imm );
			break;	
		case 8:
			result = (op2 << shamt); //store in rd
			break;	
		case 9:
			result = (op2 << op1); //store in rd
			break;	
		case 10:
			result = (op1 - op2); //store in rd
			break;	
		case 11: //lower halfword load
			result = imm << 16;  //store in rt
			break;	
		case 12:
			if(op1 < op2) {
				result = 1;
			}
			else
			{
				result = 0;
			}
			break;	
		case 13:
			if(op1 < 0){
				op1 = 4294967296 + op1;
			}
			if(imm < 0){
				imm = 4294967296 + imm;
			}
			if(op1 < imm){
				result = 1;
			}
			else
			{
				result = 0;
			}
			break;	
		case 14: //beq
			//branch on equal
			if(op1 == op2) {
				result_address = imm; //get the result_address
				ex_mem.wCond= 1;
			}
			else
			{
				result_address = 0;
				ex_mem.wCond= 0;
			}
			break;	
		case 15: //bgez
			if(op1 >= 0) {
				result_address = imm;
				ex_mem.wCond= 1;
			}
			else
			{
				result_address = 0;
				ex_mem.wCond= 0;
			}
			break;	
		case 16: //bgtz
			if(op1 > 0)
			{
				result_address = imm;
				ex_mem.wCond= 1;
			}
			else
			{
				result_address = 0;
				ex_mem.wCond= 0;
			}
			break;	
		case 17: //blez
			if(op1 <= 0) {
				result_address = imm;
				ex_mem.wCond= 1;
			}
			else
			{
				result_address = 0;
				ex_mem.wCond= 0;
			}
			break;	
		case 18: //bltz
			if(op1 < 0)
			{
				result_address = imm;
				ex_mem.wCond= 1;
			}
			else
			{
				result_address = 0;
				ex_mem.wCond= 0;
			}
			break;	
		case 19: //lb
			read_address = op1 + imm; //store to rt
			break;	
		case 20: //lw
			read_address = op1 + imm; //store to rt
			// printf("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^%d %d %d\n",op1,imm,read_address );
			break;	
		case 21: //sb
			write_address = op1 + imm;
			//memory[op1 + imm] = op2;
			break;	
		case 22: //sw
			write_address = op1 + imm;
			// printf("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^%d %d %d\n",op1,imm,write_address );
			//memory[op1 + imm] = op2; 
			break;
		case 23:
			result_address = 0;
			result = 0;
			write_address = 0;
			read_address = 0;
			break;
		case 24: //jump instruction
			result_address = imm; //get the result_address
			ex_mem.wCond = 2;
			break;
		case 25: //jump and link (write to register 31)
			//jal 
			// z = (rpc*4 + 4194304) & (4026531840);
			// result_address = z|(imm << 2);
			result_address = imm; 
			ex_mem.wCond = 2;
			result = (rpc + 1)*4 + 4194304;
			// printf("DEKHOOOOOOOOOOOOOOOOOO YEHHHHHH TARGET ADDRESS %d and RESULT %d %d %d\n",result_address,result,z,imm);

			break;
		case 26:
			//jalr
			result_address = op1;
			ex_mem.wCond = 2;
			result = (rpc + 1)*4 + 4194304;
			break;
		case 27:
			//jr
			result_address = op1;
			ex_mem.wCond = 2;
			break;
		case 28:
			result = op2; //pass the operand 1 directly
			break;
		case 29:
			result = registers[33];    //move from LO register
			break;
	}
	ex_mem.wMultResult = mult_result;
	ex_mem.wALUResult = result;
	ex_mem.wAddResult = result_address;
	ex_mem.wReadAdd = read_address;
	ex_mem.wWriteAdd = write_address;
	// printf("yay2 %d\n",ex_mem.wALUResult );
	// printf("yay3 %d\n",result );

	if(ex_mem.wCond == 1){   //IF Cond satisfied then add offset to PC.
		wpc += (result_address) / 4;
		w_pc += (result_address) / 4;
		nIdle+=2;
		ex_mem.witype = 23;
		id_ex.witype = 23;		//DO SOMETHING ABOUT RACE
		if_id.witype = 23;		//DO SOMETHING ABOUT RACE
	}

	if(ex_mem.wCond == 2)
	{
		wpc = (result_address - 4194304)/4;
		w_pc = wpc;
		nIdle+=2;
		id_ex.witype = 23;
		if_id.witype = 23;
		ex_mem.wCond = 1;
		// printf("kayyyyyyyyyyyy %d\n", wpc);
	}

	// printf("ex_ins\n");
}

void* mem_ins(void* instruction_data){

	// mem_wb.wenable = ex_mem.renable;
	// if(ex_mem.renable == 0){
	// 	// ex_mem.wenable = 1;
	// 	pthread_exit(NULL);
	// }

	mem_wb.wRs    = ex_mem.rRs;
	mem_wb.wRt    = ex_mem.rRt;
	mem_wb.wRd    = ex_mem.rRd;
	mem_wb.wrr    = ex_mem.rrr;
	mem_wb.wimm   = ex_mem.rimm;
	mem_wb.wshamt = ex_mem.rshamt;
	mem_wb.witype = ex_mem.ritype;
	mem_wb.wRsData= ex_mem.rRsData;
	mem_wb.wRtData= ex_mem.rRtData;
	mem_wb.wRrData= ex_mem.rRrData;
	mem_wb.wRdData= ex_mem.rRdData;
	mem_wb.wisRt  = ex_mem.risRt;

	
	instr* my_instruction;
	my_instruction = (instr *) instruction_data;
	//TODO
	// printf("mem_ins\n");
	// printf("MEMtype: %d\n", ex_mem.ritype);
	// printf("MEMrs: %d\n"  , ex_mem.rRs);
	// printf("MEMrt: %d\n"  , ex_mem.rRt);
	// printf("MEMrd: %d\n\n", ex_mem.rRd);
	mem_wb.wRegWrite = ex_mem.rRegWrite;
	mem_wb.wALUSrc   = ex_mem.rALUSrc;
	mem_wb.wbranch   = ex_mem.rbranch;
	mem_wb.wRegDst   = ex_mem.rRegDst;
	mem_wb.wMemRead  = ex_mem.rMemRead;
	mem_wb.wMemWrite = ex_mem.rMemWrite;
	mem_wb.wMemtoReg = ex_mem.rMemtoReg;
	mem_wb.wALUResult= ex_mem.rALUResult;
	mem_wb.wMultResult = ex_mem.rMultResult; // mult/madd
	mem_wb.wAddResult= ex_mem.rAddResult;
	mem_wb.wReadAdd  = ex_mem.rReadAdd;  
	mem_wb.wWriteAdd = ex_mem.rWriteAdd;
	// mem_wb.wWriteData= ex_mem.rWriteData; 
	mem_wb.wWriteData= registers[ex_mem.rRt];

	mem_wb.wReadData = ex_mem.rALUResult;
	mem_wb.wReadMultData = ex_mem.rMultResult;
	// printf("yay4 %d\n",mem_wb.wALUResult );
	// printf("xxxxxxxxxxxxxxxxxxxxxx%d\n", mem_wb.ritype);
	// printf("xxxxxxxxxxxxxxxxxxxxxx%d\n", mem_wb.rRegWrite);
	// printf("xxxxxxxxxxxxxxxxxxxxxx%d\n", mem_wb.rRt);
	// printf("xxxxxxxxxxxxxxxxxxxxxx%d\n", ex_mem.rRd);
	// printf("xxxxxxxxxxxxxxxxxxxxxx%d\n", ex_mem.rMemWrite);
	if(ex_mem.ritype == lw){
		if((mem_wb.rRegWrite == 1) && (mem_wb.rRt == ex_mem.rRt) && (ex_mem.rMemWrite == 1))
		{
			// printf("                               fwdM1\n");
		fprintf(trace, "%d %x\n", 0, mem_wb.rReadAdd);
		mem_wb.wReadData = memory[mem_wb.rReadAdd - 268500992];
		}else
		{
		// printf("yayayayayayaaya\n");
		// printf("**%d\n",mem_wb.wReadData );
		// printf("****%d\n",ex_mem.rReadAdd );
		// printf("yayayayaayayaya\n");
			fprintf(trace, "%d %x\n", 0, ex_mem.rReadAdd);
		mem_wb.wReadData = memory[ex_mem.rReadAdd - 268500992];
		// printf("**%d\n",mem_wb.wReadData );
		}

		nDcache++;
	}


	if(ex_mem.ritype == lb){

		if((mem_wb.rRegWrite == 1) && (mem_wb.rRt == ex_mem.rRt) && (ex_mem.rMemWrite == 1))
		{
			// printf("                               fwdM2\n");
		fprintf(trace, "%d %x\n", 0, mem_wb.rReadAdd);
		mem_wb.wReadData = memory[mem_wb.rReadAdd - 268500992];	
		}else
		{
		fprintf(trace, "%d %x\n", 0, ex_mem.rReadAdd);
		mem_wb.wReadData = memory[ex_mem.rReadAdd - 268500992];	
		}
		mem_wb.rReadData = mem_wb.rReadData & 4278190080;
		mem_wb.rReadData = mem_wb.rReadData >> 24;
		nDcache++;
	}


	if(ex_mem.ritype == sw){

		// if((mem_wb.rRegWrite == 1) && ((mem_wb.rRd == ex_mem.rRt)||(((mem_wb.ritype == 1)||(mem_wb.ritype == 7)||(mem_wb.ritype == 11))&& (mem_wb.rRt == ex_mem.rRt))) && (ex_mem.rMemWrite == 1))
		// {
		fprintf(trace, "%d %x\n", 1, ex_mem.rWriteAdd);
		if((mem_wb.rRegWrite == 1) && (ex_mem.rMemWrite == 1) && (ex_mem.ritype != nop) && (((mem_wb.risRt == 1) && (mem_wb.rRt == ex_mem.rRt)) || ((mem_wb.risRt == 0) && (mem_wb.rRd == ex_mem.rRt))) )
		{
			// printf("                               fwdM3\n");
			// printf("%d\n", mem_wb.rRegWrite);
			// printf("%d\n", mem_wb.rRd);
			// printf("%d\n", ex_mem.rRd);
			// printf("%d\n", ex_mem.rMemWrite);
			memory[ex_mem.rWriteAdd - 268500992] = mem_wb.rReadData;
		}
		else
		{
			// printf("$$$$$$$$$$$$$$$$$%d\n",mem_wb.rRegWrite);
			// printf("$$$$$$$$$$$$$$$$$%d\n",ex_mem.rMemWrite );
			// printf("$$$$$$$$$$$$$$$$$%d\n",ex_mem.ritype );
			// printf("$$$$$$$$$$$$$$$$$%d\n",mem_wb.risRt );
			// printf("$$$$$$$$$$$$$$$$$%d\n",ex_mem.rRt );
			// printf("$$$$$$$$$$$$$$$$$%d\n",mem_wb.rRt );
			// printf("$$$$$$$$$$$$$$$$$%d\n",mem_wb.rRd );
			// printf("$$$$$$$$$$$$$$$$$%d\n",mem_wb.wWriteData);
			// printf("$$$$$$$$$$$$$$$$$%d\n",ex_mem.rWriteAdd );
			memory[ex_mem.rWriteAdd - 268500992] = mem_wb.wWriteData;
			// printf("yay\n");
		}

		nDcache++;
	}


	if(ex_mem.ritype == sb){
		// if((mem_wb.rRegWrite == 1) && ((mem_wb.rRd == ex_mem.rRt)||(((mem_wb.ritype == 1)||(mem_wb.ritype == 7)||(mem_wb.ritype == 11))&& (mem_wb.rRt == ex_mem.rRt))) && (ex_mem.rMemWrite == 1))
		// {
		fprintf(trace, "%d %x\n", 1, ex_mem.rWriteAdd);
		if((mem_wb.rRegWrite == 1) && (ex_mem.rMemWrite == 1) && (ex_mem.ritype != nop) && (((mem_wb.risRt == 1) && (mem_wb.rRt == ex_mem.rRt)) || ((mem_wb.risRt == 0) && (mem_wb.rRd == ex_mem.rRt))) )
		{
			// printf("                               fwdM4\n");
			mem_wb.rReadData = mem_wb.rReadData & 255;
			memory[ex_mem.rWriteAdd - 268500992] = mem_wb.rReadData;
		}else
		{
			ex_mem.rWriteData = ex_mem.rWriteData & 255;
			memory[ex_mem.rWriteAdd - 268500992] = ex_mem.rWriteData;
		}

		nDcache++;
	}
	// printf("mem_ins\n");
}

void* write_back_ins(void* instruction_data){
	// printf("###################\n");
	// if(mem_wb.renable == 0){
	// 	// mem_wb.wenable = 1;
	// 	pthread_exit(NULL);
	// }
	instr* my_instruction;
	my_instruction = (instr *) instruction_data;
	//TODO
	// printf("write_back_ins\n");
	// printf("WBtype: %d\n", mem_wb.ritype);
	// printf("WBrs: %d\n"  , mem_wb.rRs);
	// printf("WBrt: %d\n"  , mem_wb.rRt);
	// printf("WBrd: %d\n\n", mem_wb.rRd);
	//RF Write
	switch(mem_wb.ritype)
	{
		case 0: case 2: case 29: case 28:
		case 5: case 6: case 8:
		case 9: case 10: case 12: case 26:
		case 13:
			registers[mem_wb.rRd] = mem_wb.rReadData;
			// printf("WB: registers[%d] = %d %d\n",mem_wb.rRd, registers[mem_wb.rRd], mem_wb.rALUResult );
			break;	
		case 1: case 7: case 11:
			registers[mem_wb.rRt] = mem_wb.rReadData;
			// printf("WB: registers[%d] = %d %d\n",mem_wb.rRt, registers[mem_wb.rRt], mem_wb.rALUResult );
			break;	
		case 3: case 4:
			registers[32]=mem_wb.rReadMultData >> 32;
			long long int x = (mem_wb.rReadMultData << 32);
			registers[33]=x >> 32;
			break;
		case 25: //for link register
			// printf("chal jaaaaaaaaaaaaaaaaaaaaaaaaaaaaa%d\n",mem_wb.rReadData );
			registers[31]=mem_wb.rReadData;
			break;
		case 19: //lb
			registers[mem_wb.rRt] = mem_wb.rReadData;
			// printf("WB: registers[%d] = %d %d\n",mem_wb.rRt, registers[mem_wb.rRt], mem_wb.rReadData );
			break;	
		case 20: //lw
			registers[mem_wb.rRt] = mem_wb.rReadData;
			// printf("WB: registers[%d] = %d %d\n",mem_wb.rRt, registers[mem_wb.rRt], mem_wb.rReadData );
			break;

		case 23: break;
	}
	// printf("write_back_ins\n");
}

void print_regs(){
	int i;
	for (i = 0; i < 32; i++)
	{
		printf("$%02d : 0x%08x\n",i, registers[i]);
	}
	printf("hi : 0x%08x\n", registers[32]);
	printf("lo : 0x%08x\n", registers[33]);
	printf("pc : 0x%08x\n", registers[34]*4 + 4194304);
	printf("###%d\n",r_pc );
	printf("###%d\n",rpc );
	// printf("\n");
}

int main(int argc, char* argv[]){
	int i,j;
	char* svg_file = argv[3]; 

	yyin = fopen(argv[2],"r");
	yylex();

	yyin = fopen(argv[1], "r");
	yylex(); //lexical analyser
	//create 5 thread ids
	pthread_t fetch,decode,ex,mem,wb;

	trace = fopen("trace.trace","w");

   	//threads are started OKAY
   	char s[100];
   	// Initialize and set thread joinable
	pthread_attr_t attr;
	pthread_attr_init(&attr);
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
	// printf("%d\n",nInstr );
   	int endIns = 0;
   	// while(rpc<=nInstr) // till the number of instructions
   	char ch;
   	FILE* fp1,*fp2;
   	fp2 = fopen(svg_file,"w");
   	fclose(fp2);
   	int run_continuous = 0;

   	registers[29] = 268500992 + 8000000;

   	if(nInstr<4) {
   		int number_of_steps=0;
   		switch(nInstr){
   			//-----------------------------------------------CASE 1----------------------------------------------------------
   		case 1: 
		while(1){

		if(number_of_steps == 5) break;
		else number_of_steps++;

		if(instructions[rpc].break_flag && (run_continuous == 1)){
   			run_continuous = 0;
   		}

		if(run_continuous == 0)
			scanf("%s",s);
		else{
			strcpy(s,"step");
		}

   		if(strcmp(s,"break") == 0){
   				char* break_address=(char*)malloc(100*sizeof(char));
   				scanf("%s",break_address);
   				char str[33] = "";
   				break_address = break_address + 2;
   				for(j=0;j<8;j++){
					switch(break_address[j]){
						case '0': strcat(str,"0000"); break;
				        case '1': strcat(str,"0001"); break;
			            case '2': strcat(str,"0010"); break;
			            case '3': strcat(str,"0011"); break;
			            case '4': strcat(str,"0100"); break;
			            case '5': strcat(str,"0101"); break;
			            case '6': strcat(str,"0110"); break;
			            case '7': strcat(str,"0111"); break;
			            case '8': strcat(str,"1000"); break;
			            case '9': strcat(str,"1001"); break;
			            case 'A': strcat(str,"1010"); break;
			            case 'B': strcat(str,"1011"); break;
			            case 'C': strcat(str,"1100"); break;
			            case 'D': strcat(str,"1101"); break;
			            case 'E': strcat(str,"1110"); break;
			            case 'F': strcat(str,"1111"); break;
			            case 'a': strcat(str,"1010"); break;
			            case 'b': strcat(str,"1011"); break;
			            case 'c': strcat(str,"1100"); break;
			            case 'd': strcat(str,"1101"); break;
			            case 'e': strcat(str,"1110"); break;
			            case 'f': strcat(str,"1111"); break;
					}
				}
				int base = bin_to_int(str);
   				base = base - 4194304;
   				instructions[base/4].break_flag = true;
   				continue;
   		}

	   	if(strcmp(s,"delete") == 0){
			char* break_address=(char*)malloc(100*sizeof(char));
			scanf("%s",break_address);

			char str[33] = "";
			break_address = break_address + 2;
			for(j=0;j<8;j++){
				switch(break_address[j]){
					case '0': strcat(str,"0000"); break;
			        case '1': strcat(str,"0001"); break;
		            case '2': strcat(str,"0010"); break;
		            case '3': strcat(str,"0011"); break;
		            case '4': strcat(str,"0100"); break;
		            case '5': strcat(str,"0101"); break;
		            case '6': strcat(str,"0110"); break;
		            case '7': strcat(str,"0111"); break;
		            case '8': strcat(str,"1000"); break;
		            case '9': strcat(str,"1001"); break;
		            case 'A': strcat(str,"1010"); break;
		            case 'B': strcat(str,"1011"); break;
		            case 'C': strcat(str,"1100"); break;
		            case 'D': strcat(str,"1101"); break;
		            case 'E': strcat(str,"1110"); break;
		            case 'F': strcat(str,"1111"); break;
		            case 'a': strcat(str,"1010"); break;
		            case 'b': strcat(str,"1011"); break;
		            case 'c': strcat(str,"1100"); break;
		            case 'd': strcat(str,"1101"); break;
		            case 'e': strcat(str,"1110"); break;
		            case 'f': strcat(str,"1111"); break;
				}
			}
			int base = bin_to_int(str);
			base = base - 4194304;
			instructions[base/4].break_flag = false;
			continue;
		}

   		if(strcmp((s),"regdump")==0)
   		{
   			print_regs();
   			continue;	
   		}

   		if(strcmp((s),"memdump")==0)
   		{
   			// printf("broooooooooooooooooooo\n");
   			char* base_address=(char*)malloc(100*sizeof(char));
   			int num_of_addresses=0;
   			scanf("%s",base_address);
   			scanf("%d",&num_of_addresses);

   			// int base = (strtol(base_address+2)) - 268500992;
   			// printf("%s\n",base_address + 2 );
   			char str[33] = "";
   			base_address = base_address + 2;
   			for(j=0;j<8;j++){
						switch(base_address[j]){
							case '0': strcat(str,"0000"); break;
				            case '1': strcat(str,"0001"); break;
				            case '2': strcat(str,"0010"); break;
				            case '3': strcat(str,"0011"); break;
				            case '4': strcat(str,"0100"); break;
				            case '5': strcat(str,"0101"); break;
				            case '6': strcat(str,"0110"); break;
				            case '7': strcat(str,"0111"); break;
				            case '8': strcat(str,"1000"); break;
				            case '9': strcat(str,"1001"); break;
				            case 'A': strcat(str,"1010"); break;
				            case 'B': strcat(str,"1011"); break;
				            case 'C': strcat(str,"1100"); break;
				            case 'D': strcat(str,"1101"); break;
				            case 'E': strcat(str,"1110"); break;
				            case 'F': strcat(str,"1111"); break;
				            case 'a': strcat(str,"1010"); break;
				            case 'b': strcat(str,"1011"); break;
				            case 'c': strcat(str,"1100"); break;
				            case 'd': strcat(str,"1101"); break;
				            case 'e': strcat(str,"1110"); break;
				            case 'f': strcat(str,"1111"); break;

						}
			}
			int base = bin_to_int(str);
			// printf("%s\n",base_address );
			// printf("%s\n",str );
   			base = base - 268500992;
   			for(j=0; j<num_of_addresses;j++){
				printf("Mem[%x] : 0x%x\n",j+268500992+base, memory[j+base]);
			}
   			continue;	
   		}

   		if(strcmp(s,"continue") == 0)
   		{
   			run_continuous = 1;
   		}

   		if(strcmp(s,"run") == 0)
   		{
   			run_continuous = 2;
   		}

  //  		if(strcmp(s,"step")!=0)
		// {
		// 	printf("Please Enter \"step\" to add next instruction in the pipeline \n");
		// 	continue;
		// }

   		switch(number_of_steps)
   				{
   					case 1:
   					pthread_create(&fetch,&attr,fetch_ins,(void*)&instructions[0]);       //instruction data is the current instruction
	   			   	pthread_join(fetch,NULL); 
	   			   	break;
   					case 2:
   					pthread_create(&decode,&attr,decode_ins,(void*)&instructions[0]);       //instruction data is the current instruction
	   			   	pthread_join(decode,NULL); 
	   			   	break;
   					case 3:
   					pthread_create(&ex,&attr,ex_ins,(void*)&instructions[0]);       //instruction data is the current instruction
	   			   	pthread_join(ex,NULL); 
	   			   	break;   					
   					case 4:
   					pthread_create(&mem,&attr,mem_ins,(void*)&instructions[0]);       //instruction data is the current instruction
	   			   	pthread_join(mem,NULL); 
	   			   	break;   					
   					case 5:
   					pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[0]);       //instruction data is the current instruction
	   			   	pthread_join(wb,NULL); 
	   			   	break;   					
   				}
		}			

   		break;

   		// --------------------------------------------CASE 2 ------------------------------------------------------------
   		case 2: 
   			

   			while(1){
				if(number_of_steps == 6) break;
				else number_of_steps++;

		if((instructions[rpc].break_flag) && (run_continuous == 1)){
   			run_continuous = 0;
   		}	

		if(run_continuous == 0)
			scanf("%s",s);
		else{
			strcpy(s,"step");
		}

   		if(strcmp(s,"break") == 0){
   				char* break_address=(char*)malloc(100*sizeof(char));
   				scanf("%s",break_address);
   				char str[33] = "";
   				break_address = break_address + 2;
   				for(j=0;j<8;j++){
					switch(break_address[j]){
						case '0': strcat(str,"0000"); break;
				        case '1': strcat(str,"0001"); break;
			            case '2': strcat(str,"0010"); break;
			            case '3': strcat(str,"0011"); break;
			            case '4': strcat(str,"0100"); break;
			            case '5': strcat(str,"0101"); break;
			            case '6': strcat(str,"0110"); break;
			            case '7': strcat(str,"0111"); break;
			            case '8': strcat(str,"1000"); break;
			            case '9': strcat(str,"1001"); break;
			            case 'A': strcat(str,"1010"); break;
			            case 'B': strcat(str,"1011"); break;
			            case 'C': strcat(str,"1100"); break;
			            case 'D': strcat(str,"1101"); break;
			            case 'E': strcat(str,"1110"); break;
			            case 'F': strcat(str,"1111"); break;
			            case 'a': strcat(str,"1010"); break;
			            case 'b': strcat(str,"1011"); break;
			            case 'c': strcat(str,"1100"); break;
			            case 'd': strcat(str,"1101"); break;
			            case 'e': strcat(str,"1110"); break;
			            case 'f': strcat(str,"1111"); break;
					}
				}
				int base = bin_to_int(str);
   				base = base - 4194304;
   				instructions[base/4].break_flag = true;
   				continue;
   		}

	   	if(strcmp(s,"delete") == 0){
			char* break_address=(char*)malloc(100*sizeof(char));
			scanf("%s",break_address);

			char str[33] = "";
			break_address = break_address + 2;
			for(j=0;j<8;j++){
				switch(break_address[j]){
					case '0': strcat(str,"0000"); break;
			        case '1': strcat(str,"0001"); break;
		            case '2': strcat(str,"0010"); break;
		            case '3': strcat(str,"0011"); break;
		            case '4': strcat(str,"0100"); break;
		            case '5': strcat(str,"0101"); break;
		            case '6': strcat(str,"0110"); break;
		            case '7': strcat(str,"0111"); break;
		            case '8': strcat(str,"1000"); break;
		            case '9': strcat(str,"1001"); break;
		            case 'A': strcat(str,"1010"); break;
		            case 'B': strcat(str,"1011"); break;
		            case 'C': strcat(str,"1100"); break;
		            case 'D': strcat(str,"1101"); break;
		            case 'E': strcat(str,"1110"); break;
		            case 'F': strcat(str,"1111"); break;
		            case 'a': strcat(str,"1010"); break;
		            case 'b': strcat(str,"1011"); break;
		            case 'c': strcat(str,"1100"); break;
		            case 'd': strcat(str,"1101"); break;
		            case 'e': strcat(str,"1110"); break;
		            case 'f': strcat(str,"1111"); break;
				}
			}
			int base = bin_to_int(str);
			base = base - 4194304;
			instructions[base/4].break_flag = false;
			continue;
		}

   		if(strcmp((s),"regdump")==0)
   		{
   			print_regs();
   			continue;	
   		}

   		if(strcmp((s),"memdump")==0)
   		{
   			// printf("broooooooooooooooooooo\n");
   			char* base_address=(char*)malloc(100*sizeof(char));
   			int num_of_addresses=0;
   			scanf("%s",base_address);
   			scanf("%d",&num_of_addresses);

   			// int base = (strtol(base_address+2)) - 268500992;
   			// printf("%s\n",base_address + 2 );
   			char str[33] = "";
   			base_address = base_address + 2;
   			for(j=0;j<8;j++){
						switch(base_address[j]){
							case '0': strcat(str,"0000"); break;
				            case '1': strcat(str,"0001"); break;
				            case '2': strcat(str,"0010"); break;
				            case '3': strcat(str,"0011"); break;
				            case '4': strcat(str,"0100"); break;
				            case '5': strcat(str,"0101"); break;
				            case '6': strcat(str,"0110"); break;
				            case '7': strcat(str,"0111"); break;
				            case '8': strcat(str,"1000"); break;
				            case '9': strcat(str,"1001"); break;
				            case 'A': strcat(str,"1010"); break;
				            case 'B': strcat(str,"1011"); break;
				            case 'C': strcat(str,"1100"); break;
				            case 'D': strcat(str,"1101"); break;
				            case 'E': strcat(str,"1110"); break;
				            case 'F': strcat(str,"1111"); break;
				            case 'a': strcat(str,"1010"); break;
				            case 'b': strcat(str,"1011"); break;
				            case 'c': strcat(str,"1100"); break;
				            case 'd': strcat(str,"1101"); break;
				            case 'e': strcat(str,"1110"); break;
				            case 'f': strcat(str,"1111"); break;

						}
			}
			int base = bin_to_int(str);
			// printf("%s\n",base_address );
			// printf("%s\n",str );
   			base = base - 268500992;
   			for(j=0; j<num_of_addresses;j++){
				printf("Mem[%x] : 0x%x\n",j+268500992+base, memory[j+base]);
			}
   			continue;	
   		}

   		if(strcmp(s,"continue") == 0)
   		{
   			run_continuous = 1;
   		}

   		if(strcmp(s,"run"))
   		{
   			run_continuous = 2;
   		}
			
				switch(number_of_steps) {
					case 1:
					pthread_create(&fetch,&attr,fetch_ins,(void*)&instructions[0]);       //instruction data is the current instruction
   			   		pthread_join(fetch,NULL); 
   			   		break;
					case 2:
					pthread_create(&fetch,&attr,fetch_ins,(void*)&instructions[1]); 
					pthread_create(&decode,&attr,decode_ins,(void*)&instructions[0]);       //instruction data is the current instruction
	   			   	pthread_join(fetch,NULL); 
	   			   	pthread_join(decode,NULL);
	   			   	break;
					case 3:
					pthread_create(&decode,&attr,decode_ins,(void*)&instructions[1]); 
					pthread_create(&ex,&attr,ex_ins,(void*)&instructions[0]);       //instruction data is the current instruction
	   			   	pthread_join(decode,NULL);
	   			   	pthread_join(ex,NULL); 
   			   		break;   					
					case 4:
					pthread_create(&ex,&attr,ex_ins,(void*)&instructions[1]);
					pthread_create(&mem,&attr,mem_ins,(void*)&instructions[0]);       //instruction data is the current instruction
	   			   	pthread_join(ex,NULL); 
	   			   	pthread_join(mem,NULL);
   			   		break;   					
					case 5:
					pthread_create(&mem,&attr,mem_ins,(void*)&instructions[1]);
					pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[0]);       //instruction data is the current instruction
	   			   	pthread_join(mem,NULL); 
	   			   	pthread_join(wb,NULL);
   			   		break; 
   			   	case 6:
   			   	pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[1]);       //instruction data is the current instruction
   			   	pthread_join(wb,NULL); 
   			   	break; 					
				}
	}

   			break;
   			case 3:   			
	while(1){
		if(number_of_steps == 7) break;
		else number_of_steps++;

		if((instructions[rpc].break_flag) && (run_continuous == 1)){
   			run_continuous = 0;
   		}	

		if(run_continuous == 0)
			scanf("%s",s);
		else{
			strcpy(s,"step");
		}

   		if(strcmp(s,"break") == 0){
   				char* break_address=(char*)malloc(100*sizeof(char));
   				scanf("%s",break_address);
   				char str[33] = "";
   				break_address = break_address + 2;
   				for(j=0;j<8;j++){
					switch(break_address[j]){
						case '0': strcat(str,"0000"); break;
				        case '1': strcat(str,"0001"); break;
			            case '2': strcat(str,"0010"); break;
			            case '3': strcat(str,"0011"); break;
			            case '4': strcat(str,"0100"); break;
			            case '5': strcat(str,"0101"); break;
			            case '6': strcat(str,"0110"); break;
			            case '7': strcat(str,"0111"); break;
			            case '8': strcat(str,"1000"); break;
			            case '9': strcat(str,"1001"); break;
			            case 'A': strcat(str,"1010"); break;
			            case 'B': strcat(str,"1011"); break;
			            case 'C': strcat(str,"1100"); break;
			            case 'D': strcat(str,"1101"); break;
			            case 'E': strcat(str,"1110"); break;
			            case 'F': strcat(str,"1111"); break;
			            case 'a': strcat(str,"1010"); break;
			            case 'b': strcat(str,"1011"); break;
			            case 'c': strcat(str,"1100"); break;
			            case 'd': strcat(str,"1101"); break;
			            case 'e': strcat(str,"1110"); break;
			            case 'f': strcat(str,"1111"); break;
					}
				}
				int base = bin_to_int(str);
   				base = base - 4194304;
   				instructions[base/4].break_flag = true;
   				continue;
   		}

	   	if(strcmp(s,"delete") == 0){
			char* break_address=(char*)malloc(100*sizeof(char));
			scanf("%s",break_address);

			char str[33] = "";
			break_address = break_address + 2;
			for(j=0;j<8;j++){
				switch(break_address[j]){
					case '0': strcat(str,"0000"); break;
			        case '1': strcat(str,"0001"); break;
		            case '2': strcat(str,"0010"); break;
		            case '3': strcat(str,"0011"); break;
		            case '4': strcat(str,"0100"); break;
		            case '5': strcat(str,"0101"); break;
		            case '6': strcat(str,"0110"); break;
		            case '7': strcat(str,"0111"); break;
		            case '8': strcat(str,"1000"); break;
		            case '9': strcat(str,"1001"); break;
		            case 'A': strcat(str,"1010"); break;
		            case 'B': strcat(str,"1011"); break;
		            case 'C': strcat(str,"1100"); break;
		            case 'D': strcat(str,"1101"); break;
		            case 'E': strcat(str,"1110"); break;
		            case 'F': strcat(str,"1111"); break;
		            case 'a': strcat(str,"1010"); break;
		            case 'b': strcat(str,"1011"); break;
		            case 'c': strcat(str,"1100"); break;
		            case 'd': strcat(str,"1101"); break;
		            case 'e': strcat(str,"1110"); break;
		            case 'f': strcat(str,"1111"); break;
				}
			}
			int base = bin_to_int(str);
			base = base - 4194304;
			instructions[base/4].break_flag = false;
			continue;
		}

   		if(strcmp((s),"regdump")==0)
   		{
   			print_regs();
   			continue;	
   		}

   		if(strcmp((s),"memdump")==0)
   		{
   			// printf("broooooooooooooooooooo\n");
   			char* base_address=(char*)malloc(100*sizeof(char));
   			int num_of_addresses=0;
   			scanf("%s",base_address);
   			scanf("%d",&num_of_addresses);

   			// int base = (strtol(base_address+2)) - 268500992;
   			// printf("%s\n",base_address + 2 );
   			char str[33] = "";
   			base_address = base_address + 2;
   			for(j=0;j<8;j++){
						switch(base_address[j]){
							case '0': strcat(str,"0000"); break;
				            case '1': strcat(str,"0001"); break;
				            case '2': strcat(str,"0010"); break;
				            case '3': strcat(str,"0011"); break;
				            case '4': strcat(str,"0100"); break;
				            case '5': strcat(str,"0101"); break;
				            case '6': strcat(str,"0110"); break;
				            case '7': strcat(str,"0111"); break;
				            case '8': strcat(str,"1000"); break;
				            case '9': strcat(str,"1001"); break;
				            case 'A': strcat(str,"1010"); break;
				            case 'B': strcat(str,"1011"); break;
				            case 'C': strcat(str,"1100"); break;
				            case 'D': strcat(str,"1101"); break;
				            case 'E': strcat(str,"1110"); break;
				            case 'F': strcat(str,"1111"); break;
				            case 'a': strcat(str,"1010"); break;
				            case 'b': strcat(str,"1011"); break;
				            case 'c': strcat(str,"1100"); break;
				            case 'd': strcat(str,"1101"); break;
				            case 'e': strcat(str,"1110"); break;
				            case 'f': strcat(str,"1111"); break;

						}
			}
			int base = bin_to_int(str);
			// printf("%s\n",base_address );
			// printf("%s\n",str );
   			base = base - 268500992;
   			for(j=0; j<num_of_addresses;j++){
				printf("Mem[%x] : 0x%x\n",j+268500992+base, memory[j+base]);
			}
   			continue;	
   		}

   		if(strcmp(s,"continue") == 0)
   		{
   			run_continuous = 1;
   			printf("broooooooooooooooooooooo3\n");
   			// continue;
   		}

   		if(strcmp(s,"run") == 0)
   		{
   			run_continuous = 2;
   		}
			
  //  		if(strcmp(s,"step")!=0)
		// {
		// 	printf("Please Enter \"step\" to add next instruction in the pipeline \n");
		// 	// continue;
		// }

			switch(number_of_steps)
			{
				case 1:
				pthread_create(&fetch,&attr,fetch_ins,(void*)&instructions[0]);       //instruction data is the current instruction
			   	pthread_join(fetch,NULL); 
			   	break;
				case 2:
				pthread_create(&fetch,&attr,fetch_ins,(void*)&instructions[1]); 
				pthread_create(&decode,&attr,decode_ins,(void*)&instructions[0]);       //instruction data is the current instruction
			   	pthread_join(fetch,NULL); 
			   	pthread_join(decode,NULL);
			   	break;
				case 3:
				pthread_create(&fetch,&attr,fetch_ins,(void*)&instructions[2]); 
				pthread_create(&decode,&attr,decode_ins,(void*)&instructions[1]); 
				pthread_create(&ex,&attr,ex_ins,(void*)&instructions[0]);       //instruction data is the current instruction
			   	pthread_join(decode,NULL);
			   	pthread_join(ex,NULL);
			   	pthread_join(fetch,NULL); 
			   	break;   					
				case 4:
				pthread_create(&decode,&attr,decode_ins,(void*)&instructions[2]); 
				pthread_create(&ex,&attr,ex_ins,(void*)&instructions[1]);
				pthread_create(&mem,&attr,mem_ins,(void*)&instructions[0]);       //instruction data is the current instruction
			   	pthread_join(ex,NULL); 
			   	pthread_join(mem,NULL);
			   	pthread_join(decode,NULL);
			   	break;   					
				case 5:
				pthread_create(&ex,&attr,ex_ins,(void*)&instructions[2]);
				pthread_create(&mem,&attr,mem_ins,(void*)&instructions[1]);
				pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[0]);       //instruction data is the current instruction
			   	pthread_join(mem,NULL); 
			   	pthread_join(wb,NULL);
			   	pthread_join(ex,NULL);
			   	break; 
			   	case 6:
			   	pthread_create(&mem,&attr,mem_ins,(void*)&instructions[2]);
			   	pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[1]);       //instruction data is the current instruction
			   	pthread_join(wb,NULL);
			   	pthread_join(mem,NULL); 
			   	break; 	
			   	case 7:
			   	pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[2]);
			   	pthread_join(wb,NULL); 	
			   	break;			
			}
   	}

   			break;
   		}
   	}
   	else{
   		while(1){

   		if(instructions[rpc].break_flag && (run_continuous == 1)){
   			run_continuous = 0;
   		}

			if(run_continuous == 0)
   				scanf("%s",s);
   			else{
   				strcpy(s,"step");
   			}

   		if(strcmp(s,"break") == 0){
   				char* break_address=(char*)malloc(100*sizeof(char));
   				scanf("%s",break_address);
   				char str[33] = "";
   				break_address = break_address + 2;
   				for(j=0;j<8;j++){
					switch(break_address[j]){
						case '0': strcat(str,"0000"); break;
				        case '1': strcat(str,"0001"); break;
			            case '2': strcat(str,"0010"); break;
			            case '3': strcat(str,"0011"); break;
			            case '4': strcat(str,"0100"); break;
			            case '5': strcat(str,"0101"); break;
			            case '6': strcat(str,"0110"); break;
			            case '7': strcat(str,"0111"); break;
			            case '8': strcat(str,"1000"); break;
			            case '9': strcat(str,"1001"); break;
			            case 'A': strcat(str,"1010"); break;
			            case 'B': strcat(str,"1011"); break;
			            case 'C': strcat(str,"1100"); break;
			            case 'D': strcat(str,"1101"); break;
			            case 'E': strcat(str,"1110"); break;
			            case 'F': strcat(str,"1111"); break;
			            case 'a': strcat(str,"1010"); break;
			            case 'b': strcat(str,"1011"); break;
			            case 'c': strcat(str,"1100"); break;
			            case 'd': strcat(str,"1101"); break;
			            case 'e': strcat(str,"1110"); break;
			            case 'f': strcat(str,"1111"); break;
					}
				}
				int base = bin_to_int(str);
   				base = base - 4194304;
   				instructions[base/4].break_flag = true;
   				continue;
   		}

	   	if(strcmp(s,"delete") == 0){
			char* break_address=(char*)malloc(100*sizeof(char));
			scanf("%s",break_address);

			char str[33] = "";
			break_address = break_address + 2;
			for(j=0;j<8;j++){
				switch(break_address[j]){
					case '0': strcat(str,"0000"); break;
			        case '1': strcat(str,"0001"); break;
		            case '2': strcat(str,"0010"); break;
		            case '3': strcat(str,"0011"); break;
		            case '4': strcat(str,"0100"); break;
		            case '5': strcat(str,"0101"); break;
		            case '6': strcat(str,"0110"); break;
		            case '7': strcat(str,"0111"); break;
		            case '8': strcat(str,"1000"); break;
		            case '9': strcat(str,"1001"); break;
		            case 'A': strcat(str,"1010"); break;
		            case 'B': strcat(str,"1011"); break;
		            case 'C': strcat(str,"1100"); break;
		            case 'D': strcat(str,"1101"); break;
		            case 'E': strcat(str,"1110"); break;
		            case 'F': strcat(str,"1111"); break;
		            case 'a': strcat(str,"1010"); break;
		            case 'b': strcat(str,"1011"); break;
		            case 'c': strcat(str,"1100"); break;
		            case 'd': strcat(str,"1101"); break;
		            case 'e': strcat(str,"1110"); break;
		            case 'f': strcat(str,"1111"); break;
				}
			}
			int base = bin_to_int(str);
			base = base - 4194304;
			instructions[base/4].break_flag = false;
			continue;
		}

   		if(strcmp((s),"regdump")==0)
   		{
   			print_regs();
   			continue;	
   		}

   		if(strcmp((s),"memdump")==0)
   		{
   			// printf("broooooooooooooooooooo\n");
   			char* base_address=(char*)malloc(100*sizeof(char));
   			int num_of_addresses=0;
   			scanf("%s",base_address);
   			scanf("%d",&num_of_addresses);

   			// int base = (strtol(base_address+2)) - 268500992;
   			// printf("%s\n",base_address + 2 );
   			char str[33] = "";
   			base_address = base_address + 2;
   			for(j=0;j<8;j++){
						switch(base_address[j]){
							case '0': strcat(str,"0000"); break;
				            case '1': strcat(str,"0001"); break;
				            case '2': strcat(str,"0010"); break;
				            case '3': strcat(str,"0011"); break;
				            case '4': strcat(str,"0100"); break;
				            case '5': strcat(str,"0101"); break;
				            case '6': strcat(str,"0110"); break;
				            case '7': strcat(str,"0111"); break;
				            case '8': strcat(str,"1000"); break;
				            case '9': strcat(str,"1001"); break;
				            case 'A': strcat(str,"1010"); break;
				            case 'B': strcat(str,"1011"); break;
				            case 'C': strcat(str,"1100"); break;
				            case 'D': strcat(str,"1101"); break;
				            case 'E': strcat(str,"1110"); break;
				            case 'F': strcat(str,"1111"); break;
				            case 'a': strcat(str,"1010"); break;
				            case 'b': strcat(str,"1011"); break;
				            case 'c': strcat(str,"1100"); break;
				            case 'd': strcat(str,"1101"); break;
				            case 'e': strcat(str,"1110"); break;
				            case 'f': strcat(str,"1111"); break;

						}
			}
			int base = bin_to_int(str);
			// printf("%s\n",base_address );
			// printf("%s\n",str );
   			base = base - 268500992;
   			for(j=0; j<num_of_addresses;j++){
				printf("Mem[%x] : 0x%x\n",j+268500992+base, memory[j+base]);
			}
   			continue;	
   		}

   		if(strcmp(s,"continue") == 0)
   		{
   			run_continuous = 1;
   			// continue;
   		}

   		if(strcmp(s,"run") == 0)
   		{
   			run_continuous = 2;
   		}


	   	if(rpc<nInstr){	
	   		switch(rpc){
	   			case 0:
	   			   	pthread_create(&fetch,&attr,fetch_ins,(void*)&instructions[0]);       //instruction data is the current instruction
	   				pthread_create(&decode,&attr,decode_ins,(void*)&instructions[0]);
	   				pthread_create(&ex,&attr,ex_ins,(void*)&instructions[0]);
	   				pthread_create(&mem,&attr,mem_ins,(void*)&instructions[0]);
	   				pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[0]);
	   			   	pthread_join(fetch,NULL);
	   			   	pthread_join(decode,NULL);
	   			   	pthread_join(ex,NULL);
					pthread_join(mem,NULL);
					pthread_join(wb,NULL);

	   			   	fp1 = fopen("./svg/procfinal1.svg","r");
	   			   	fp2 = fopen(svg_file,"w");
	   			   	while(1)
	   			   	{
	   			   		ch = fgetc(fp1);
	   			   		if(ch == EOF)
	   			   			break;
	   			   		else
	   			   			putc(ch,fp2);
	   			   	}
	   			   	// printf("####################################################################### File copied Successfully!\n");
   					fclose(fp1);
   					fclose(fp2);

   	char buff[BUFSIZ];      // the input line
    char newbuff[BUFSIZ];   // the results of any editing
    //printf("ttttttttttttttttttt%s\n",instructions[0].ins_name);
    char findme[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>";
    char replacewith1[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith2[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith3[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith4[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith5[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    FILE *in, *out;
    int flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );

    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>\n",instructions[0].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
        while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith2);
            flag=1;
        } else {
            strcpy( newbuff, buff );
        }
        fputs( newbuff, out );
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
        while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith3);
            flag=1;
        } else {
            strcpy( newbuff, buff );
        }
        fputs( newbuff, out );
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
        while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith4);
            flag=1;
        } else {
            strcpy( newbuff, buff );
        }
        fputs( newbuff, out );
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
        while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith5);
            flag=1;
        } else {
            strcpy( newbuff, buff );
        }
        fputs( newbuff, out );
    }
        fclose( in );
    fclose( out );

    remove(svg_file);
    rename("replica.svg",svg_file);

	   			   	nCycle++;
	   			   	nIdle++;
	   			   	nIexe++;
	   			   	nIcache++;
	   				break;
	   			case 1:
	   			   	pthread_create(&fetch,&attr,fetch_ins,(void*)&instructions[1]);       //instruction data is the current instruction
	   				pthread_create(&decode,&attr,decode_ins,(void*)&instructions[0]);
	   				pthread_create(&ex,&attr,ex_ins,(void*)&instructions[0]);
	   				pthread_create(&mem,&attr,mem_ins,(void*)&instructions[0]);
	   				pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[0]);
	   				pthread_join(fetch,NULL);
					pthread_join(decode,NULL);
					pthread_join(ex,NULL);
					pthread_join(mem,NULL);
					pthread_join(wb,NULL);


					fp1 = fopen("./svg/procfinal12.svg","r");
	   			   	fp2 = fopen(svg_file,"w");
	   			   	while(1)
	   			   	{
	   			   		ch = fgetc(fp1);
	   			   		if(ch == EOF)
	   			   			break;
	   			   		else
	   			   			putc(ch,fp2);
	   			   	}
	   			   	// printf("####################################################################### File copied Successfully!\n");
   					fclose(fp1);
   					fclose(fp2);

    flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );

    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>\n",instructions[1].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>\n",instructions[0].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
        while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith3);
            flag=1;
        } else {
            strcpy( newbuff, buff );
        }
        fputs( newbuff, out );
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
        while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith4);
            flag=1;
        } else {
            strcpy( newbuff, buff );
        }
        fputs( newbuff, out );
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
        while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith5);
            flag=1;
        } else {
            strcpy( newbuff, buff );
        }
        fputs( newbuff, out );
    }
        fclose( in );
    fclose( out );

    remove(svg_file);
    rename("replica.svg",svg_file);
					nCycle++;
					nIdle++;
					nIexe++;
					nIcache++;
	   				break;
	   			case 2:
	   			   	pthread_create(&fetch,&attr,fetch_ins,(void*)&instructions[2]);       //instruction data is the current instruction
	   				pthread_create(&decode,&attr,decode_ins,(void*)&instructions[1]);
	   				pthread_create(&ex,&attr,ex_ins,(void*)&instructions[0]);
	   				pthread_create(&mem,&attr,mem_ins,(void*)&instructions[0]);
	   				pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[0]);
	   				
	   				pthread_join(fetch,NULL);
					pthread_join(decode,NULL);
					pthread_join(ex,NULL);
					pthread_join(mem,NULL);
					pthread_join(wb,NULL);

					fp1 = fopen("./svg/procfinal123.svg","r");
	   			   	fp2 = fopen(svg_file,"w");
	   			   	while(1)
	   			   	{
	   			   		ch = fgetc(fp1);
	   			   		if(ch == EOF)
	   			   			break;
	   			   		else
	   			   			putc(ch,fp2);
	   			   	}
	   			   	// printf("#######################################################################File copied Successfully!");
   					fclose(fp1);
   					fclose(fp2);

	flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );

    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>\n",instructions[2].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>\n",instructions[1].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>\n",instructions[0].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
        while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith4);
            flag=1;
        } else {
            strcpy( newbuff, buff );
        }
        fputs( newbuff, out );
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
        while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith5);
            flag=1;
        } else {
            strcpy( newbuff, buff );
        }
        fputs( newbuff, out );
    }
        fclose( in );
    fclose( out );

    remove(svg_file);
    rename("replica.svg",svg_file);
					nCycle++;
					nIdle++;
					nIexe++;
					nIcache++;
	   				break;
	   			case 3:
	   			   	pthread_create(&fetch,&attr,fetch_ins,(void*)&instructions[3]);       //instruction data is the current instruction
	   				pthread_create(&decode,&attr,decode_ins,(void*)&instructions[2]);
	   				pthread_create(&ex,&attr,ex_ins,(void*)&instructions[1]);
	   				pthread_create(&mem,&attr,mem_ins,(void*)&instructions[0]);
	   				pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[0]);
	   				pthread_join(fetch,NULL);
					pthread_join(decode,NULL);
					pthread_join(ex,NULL);
					pthread_join(mem,NULL);
					pthread_join(wb,NULL);

					fp1 = fopen("./svg/procfinal1234.svg","r");
	   			   	fp2 = fopen(svg_file,"w");
	   			   	while(1)
	   			   	{
	   			   		ch = fgetc(fp1);
	   			   		if(ch == EOF)
	   			   			break;
	   			   		else
	   			   			putc(ch,fp2);
	   			   	}
	   			   	// printf("#######################################################################File copied Successfully!");
   					fclose(fp1);
   					fclose(fp2);

   					flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );

    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>\n",instructions[3].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>\n",instructions[2].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>\n",instructions[1].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>\n",instructions[0].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
        while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith5);
            flag=1;
        } else {
            strcpy( newbuff, buff );
        }
        fputs( newbuff, out );
    }
        fclose( in );
    fclose( out );

    remove(svg_file);
    rename("replica.svg",svg_file);

					nCycle++;
					nIdle++;
					nIexe++;
					nIcache++;
					// printf("yay3\n");
	   				break;

	   			default:
	   			   	pthread_create(&fetch,&attr,fetch_ins,(void*)&instructions[rpc]);       //instruction data is the current instruction
	   				pthread_create(&decode,&attr,decode_ins,(void*)&instructions[rpc-1]);
	   				pthread_create(&ex,&attr,ex_ins,(void*)&instructions[rpc-2]);
	   				pthread_create(&mem,&attr,mem_ins,(void*)&instructions[rpc-3]);
	   				pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[rpc-4]);
	   				pthread_join(fetch,NULL);
					pthread_join(decode,NULL);
					pthread_join(ex,NULL);
					pthread_join(mem,NULL);
					pthread_join(wb,NULL);

					fp1 = fopen("./svg/procfinal12345.svg","r");
	   			   	fp2 = fopen(svg_file,"w");
	   			   	while(1)
	   			   	{
	   			   		ch = fgetc(fp1);
	   			   		if(ch == EOF)
	   			   			break;
	   			   		else
	   			   			putc(ch,fp2);
	   			   	}
	   			   	// printf("#######################################################################File copied Successfully!");
   					fclose(fp1);
   					fclose(fp2);

   					strcpy(findme ,"         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063475px\">--------</tspan></text>");

   					flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );

    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063475px\">%s</tspan></text>",instructions[rpc].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063475px\">%s</tspan></text>",instructions[rpc-1].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
           fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063475px\">%s</tspan></text>",instructions[rpc-2].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063475px\">%s</tspan></text>",instructions[rpc-3].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063475px\">%s</tspan></text>",instructions[rpc-4].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );

    remove(svg_file);
    rename("replica.svg",svg_file);

					nCycle++;
					nIexe++;
					nIcache++;
					// printf("&&&&&&&&&&&&&&&&&&&&&&&&&&7yay4\n");			
	   		}
	   	

   		//join and sync rw regs
	   		print_regs();

	   		rpc = wpc;
	   		r_pc = w_pc;
	   		registers[34] = wpc;
			if_id.rPCSrc     = if_id.wPCSrc    ;   					
			if_id.rRegWrite  = if_id.wRegWrite ;   	
			if_id.rALUSrc    = if_id.wALUSrc   ;  		  
			if_id.rALUOp     = if_id.wALUOp    ; 					
			if_id.rRegDst    = if_id.wRegDst   ; 		  
			if_id.rbranch    = if_id.wbranch   ;				
			if_id.rMemRead   = if_id.wMemRead  ;	 
			if_id.rMemWrite  = if_id.wMemWrite ; 	
			if_id.rMemtoReg  = if_id.wMemtoReg ; 	
			if_id.rRs        = if_id.wRs       ; 	     
			if_id.rRt        = if_id.wRt       ; 	    
			if_id.rRd        = if_id.wRd       ;   
			if_id.rALUResult = if_id.wALUResult;
			if_id.rMultResult = if_id.wMultResult;	
			if_id.rAddResult = if_id.wAddResult;	
			if_id.rReadAdd   = if_id.wReadAdd  ;		
			if_id.rWriteAdd  = if_id.wWriteAdd ;				
			if_id.rCond      = if_id.wCond     ;				
			if_id.rReadData  = if_id.wReadData ;
			if_id.rReadMultData = if_id.wReadMultData;
			if_id.rrr    = if_id.wrr;
			if_id.rimm   = if_id.wimm;
			if_id.rshamt = if_id.wshamt;
			if_id.ritype = if_id.witype;

			id_ex.rPCSrc     = id_ex.wPCSrc    ;
			id_ex.rRegWrite  = id_ex.wRegWrite ;
			id_ex.rALUSrc    = id_ex.wALUSrc   ;
			id_ex.rALUOp     = id_ex.wALUOp    ;
			id_ex.rRegDst    = id_ex.wRegDst   ;
			id_ex.rbranch    = id_ex.wbranch   ;
			id_ex.rMemRead   = id_ex.wMemRead  ;
			id_ex.rMemWrite  = id_ex.wMemWrite ;
			id_ex.rMemtoReg  = id_ex.wMemtoReg ;
			id_ex.rRs        = id_ex.wRs       ;
			id_ex.rRt        = id_ex.wRt       ;
			id_ex.rRd        = id_ex.wRd       ;
			id_ex.rALUResult = id_ex.wALUResult;
			id_ex.rMultResult = id_ex.wMultResult;
			id_ex.rAddResult = id_ex.wAddResult;
			id_ex.rReadAdd   = id_ex.wReadAdd  ;
			id_ex.rWriteAdd  = id_ex.wWriteAdd ;
			id_ex.rCond      = id_ex.wCond     ;
			id_ex.rReadData  = id_ex.wReadData ;
			id_ex.rReadMultData = id_ex.wReadMultData;
			id_ex.rrr    = id_ex.wrr;
			id_ex.rimm   = id_ex.wimm;
			id_ex.rshamt = id_ex.wshamt;
			id_ex.ritype = id_ex.witype;

			ex_mem.rPCSrc     = ex_mem.wPCSrc    ;
			ex_mem.rRegWrite  = ex_mem.wRegWrite ;
			ex_mem.rALUSrc    = ex_mem.wALUSrc   ;
			ex_mem.rALUOp     = ex_mem.wALUOp    ;
			ex_mem.rRegDst    = ex_mem.wRegDst   ;
			ex_mem.rbranch    = ex_mem.wbranch   ;
			ex_mem.rMemRead   = ex_mem.wMemRead  ;
			ex_mem.rMemWrite  = ex_mem.wMemWrite ;
			ex_mem.rMemtoReg  = ex_mem.wMemtoReg ;
			ex_mem.rRs        = ex_mem.wRs       ;
			ex_mem.rRt        = ex_mem.wRt       ;
			ex_mem.rRd        = ex_mem.wRd       ;
			ex_mem.rALUResult = ex_mem.wALUResult;
			ex_mem.rMultResult = ex_mem.wMultResult;
			ex_mem.rAddResult = ex_mem.wAddResult;
			ex_mem.rReadAdd   = ex_mem.wReadAdd  ;
			ex_mem.rWriteAdd  = ex_mem.wWriteAdd ;
			ex_mem.rCond      = ex_mem.wCond     ;
			ex_mem.rReadData  = ex_mem.wReadData ;
			ex_mem.rReadMultData = ex_mem.wReadMultData;
			ex_mem.rrr    = ex_mem.wrr;
			ex_mem.rimm   = ex_mem.wimm;
			ex_mem.rshamt = ex_mem.wshamt;
			ex_mem.ritype = ex_mem.witype;

			mem_wb.rPCSrc     = mem_wb.wPCSrc    ;
			mem_wb.rRegWrite  = mem_wb.wRegWrite ;
			mem_wb.rALUSrc    = mem_wb.wALUSrc   ;
			mem_wb.rALUOp     = mem_wb.wALUOp    ;
			mem_wb.rRegDst    = mem_wb.wRegDst   ;
			mem_wb.rbranch    = mem_wb.wbranch   ;
			mem_wb.rMemRead   = mem_wb.wMemRead  ;
			mem_wb.rMemWrite  = mem_wb.wMemWrite ;
			mem_wb.rMemtoReg  = mem_wb.wMemtoReg ;
			mem_wb.rRs        = mem_wb.wRs       ;
			mem_wb.rRt        = mem_wb.wRt       ;
			mem_wb.rRd        = mem_wb.wRd       ;
			mem_wb.rALUResult = mem_wb.wALUResult;
			mem_wb.rMultResult = mem_wb.wMultResult;
			mem_wb.rAddResult = mem_wb.wAddResult;
			mem_wb.rReadAdd   = mem_wb.wReadAdd  ;
			mem_wb.rWriteAdd  = mem_wb.wWriteAdd ;
			mem_wb.rCond      = mem_wb.wCond     ;
			mem_wb.rReadData  = mem_wb.wReadData ;
			mem_wb.rReadMultData = mem_wb.wReadMultData;
			mem_wb.rrr    = mem_wb.wrr;
			mem_wb.rimm   = mem_wb.wimm;
			mem_wb.rshamt = mem_wb.wshamt;
			mem_wb.ritype = mem_wb.witype;

			if_id.rWriteData  = if_id.wWriteData ;
			id_ex.rWriteData  = id_ex.wWriteData ;
			ex_mem.rWriteData  = ex_mem.wWriteData ;
			mem_wb.rWriteData  = mem_wb.wWriteData ;
			if_id.rRsData= if_id.wRsData;
			id_ex.rRtData= id_ex.wRtData;
			ex_mem.rRrData= ex_mem.wRrData;
			mem_wb.rRdData= mem_wb.wRdData;
			if_id.renable= if_id.wenable;
			id_ex.renable= id_ex.wenable;
			ex_mem.renable= ex_mem.wenable;
			mem_wb.renable= mem_wb.wenable;
			if_id.risRt= if_id.wisRt;
			id_ex.risRt= id_ex.wisRt;
			ex_mem.risRt= ex_mem.wisRt;
			mem_wb.risRt= mem_wb.wisRt;

		}
		else{

			// if(endIns == 0){
			if(r_pc==nInstr){
				// printf("LAST STAGE0\n");
	   				pthread_create(&decode,&attr,decode_ins,(void*)&instructions[rpc-1]);
	   				pthread_create(&ex,&attr,ex_ins,(void*)&instructions[rpc-2]);
	   				pthread_create(&mem,&attr,mem_ins,(void*)&instructions[rpc-3]);
	   				pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[rpc-4]);

					pthread_join(decode,NULL);
					pthread_join(ex,NULL);
					pthread_join(mem,NULL);
					pthread_join(wb,NULL);

					fp1 = fopen("./svg/procfinal2345.svg","r");
	   			   	fp2 = fopen(svg_file,"w");
	   			   	while(1)
	   			   	{
	   			   		ch = fgetc(fp1);
	   			   		if(ch == EOF)
	   			   			break;
	   			   		else
	   			   			putc(ch,fp2);
	   			   	}
	   			   	// printf("#######################################################################File copied Successfully!");
   					fclose(fp1);
   					fclose(fp2);

   	char buff[BUFSIZ];      // the input line
    char newbuff[BUFSIZ];   // the results of any editing
    //printf("ttttttttttttttttttt%s\n",instructions[0].ins_name);
    char findme[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>";
    char replacewith1[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith2[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith3[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith4[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith5[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    FILE *in, *out;
    int flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );

    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">********</tspan></text>");
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>",instructions[rpc-1].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
           fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>",instructions[rpc-2].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>",instructions[rpc-3].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>",instructions[rpc-4].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );

    remove(svg_file);
    rename("replica.svg",svg_file);

	   				nCycle++;
	   				w_pc++;
	   				rpc = wpc;
	   				r_pc = w_pc;
	   				registers[34] = wpc;
	   				if_id.rPCSrc     = if_id.wPCSrc    ;   					
			if_id.rPCSrc     = if_id.wPCSrc    ;   					
			if_id.rRegWrite  = if_id.wRegWrite ;   	
			if_id.rALUSrc    = if_id.wALUSrc   ;  		  
			if_id.rALUOp     = if_id.wALUOp    ; 					
			if_id.rRegDst    = if_id.wRegDst   ; 		  
			if_id.rbranch    = if_id.wbranch   ;				
			if_id.rMemRead   = if_id.wMemRead  ;	 
			if_id.rMemWrite  = if_id.wMemWrite ; 	
			if_id.rMemtoReg  = if_id.wMemtoReg ; 	
			if_id.rRs        = if_id.wRs       ; 	     
			if_id.rRt        = if_id.wRt       ; 	    
			if_id.rRd        = if_id.wRd       ;   
			if_id.rALUResult = if_id.wALUResult;
			if_id.rMultResult = if_id.wMultResult;	
			if_id.rAddResult = if_id.wAddResult;	
			if_id.rReadAdd   = if_id.wReadAdd  ;		
			if_id.rWriteAdd  = if_id.wWriteAdd ;				
			if_id.rCond      = if_id.wCond     ;				
			if_id.rReadData  = if_id.wReadData ;
			if_id.rReadMultData = if_id.wReadMultData;
			if_id.rrr    = if_id.wrr;
			if_id.rimm   = if_id.wimm;
			if_id.rshamt = if_id.wshamt;
			if_id.ritype = if_id.witype;

			id_ex.rPCSrc     = id_ex.wPCSrc    ;
			id_ex.rRegWrite  = id_ex.wRegWrite ;
			id_ex.rALUSrc    = id_ex.wALUSrc   ;
			id_ex.rALUOp     = id_ex.wALUOp    ;
			id_ex.rRegDst    = id_ex.wRegDst   ;
			id_ex.rbranch    = id_ex.wbranch   ;
			id_ex.rMemRead   = id_ex.wMemRead  ;
			id_ex.rMemWrite  = id_ex.wMemWrite ;
			id_ex.rMemtoReg  = id_ex.wMemtoReg ;
			id_ex.rRs        = id_ex.wRs       ;
			id_ex.rRt        = id_ex.wRt       ;
			id_ex.rRd        = id_ex.wRd       ;
			id_ex.rALUResult = id_ex.wALUResult;
			id_ex.rMultResult = id_ex.wMultResult;
			id_ex.rAddResult = id_ex.wAddResult;
			id_ex.rReadAdd   = id_ex.wReadAdd  ;
			id_ex.rWriteAdd  = id_ex.wWriteAdd ;
			id_ex.rCond      = id_ex.wCond     ;
			id_ex.rReadData  = id_ex.wReadData ;
			id_ex.rReadMultData = id_ex.wReadMultData;
			id_ex.rrr    = id_ex.wrr;
			id_ex.rimm   = id_ex.wimm;
			id_ex.rshamt = id_ex.wshamt;
			id_ex.ritype = id_ex.witype;

			ex_mem.rPCSrc     = ex_mem.wPCSrc    ;
			ex_mem.rRegWrite  = ex_mem.wRegWrite ;
			ex_mem.rALUSrc    = ex_mem.wALUSrc   ;
			ex_mem.rALUOp     = ex_mem.wALUOp    ;
			ex_mem.rRegDst    = ex_mem.wRegDst   ;
			ex_mem.rbranch    = ex_mem.wbranch   ;
			ex_mem.rMemRead   = ex_mem.wMemRead  ;
			ex_mem.rMemWrite  = ex_mem.wMemWrite ;
			ex_mem.rMemtoReg  = ex_mem.wMemtoReg ;
			ex_mem.rRs        = ex_mem.wRs       ;
			ex_mem.rRt        = ex_mem.wRt       ;
			ex_mem.rRd        = ex_mem.wRd       ;
			ex_mem.rALUResult = ex_mem.wALUResult;
			ex_mem.rMultResult = ex_mem.wMultResult;
			ex_mem.rAddResult = ex_mem.wAddResult;
			ex_mem.rReadAdd   = ex_mem.wReadAdd  ;
			ex_mem.rWriteAdd  = ex_mem.wWriteAdd ;
			ex_mem.rCond      = ex_mem.wCond     ;
			ex_mem.rReadData  = ex_mem.wReadData ;
			ex_mem.rReadMultData = ex_mem.wReadMultData;
			ex_mem.rrr    = ex_mem.wrr;
			ex_mem.rimm   = ex_mem.wimm;
			ex_mem.rshamt = ex_mem.wshamt;
			ex_mem.ritype = ex_mem.witype;

			mem_wb.rPCSrc     = mem_wb.wPCSrc    ;
			mem_wb.rRegWrite  = mem_wb.wRegWrite ;
			mem_wb.rALUSrc    = mem_wb.wALUSrc   ;
			mem_wb.rALUOp     = mem_wb.wALUOp    ;
			mem_wb.rRegDst    = mem_wb.wRegDst   ;
			mem_wb.rbranch    = mem_wb.wbranch   ;
			mem_wb.rMemRead   = mem_wb.wMemRead  ;
			mem_wb.rMemWrite  = mem_wb.wMemWrite ;
			mem_wb.rMemtoReg  = mem_wb.wMemtoReg ;
			mem_wb.rRs        = mem_wb.wRs       ;
			mem_wb.rRt        = mem_wb.wRt       ;
			mem_wb.rRd        = mem_wb.wRd       ;
			mem_wb.rALUResult = mem_wb.wALUResult;
			mem_wb.rMultResult = mem_wb.wMultResult;
			mem_wb.rAddResult = mem_wb.wAddResult;
			mem_wb.rReadAdd   = mem_wb.wReadAdd  ;
			mem_wb.rWriteAdd  = mem_wb.wWriteAdd ;
			mem_wb.rCond      = mem_wb.wCond     ;
			mem_wb.rReadData  = mem_wb.wReadData ;
			mem_wb.rReadMultData = mem_wb.wReadMultData;
			mem_wb.rrr    = mem_wb.wrr;
			mem_wb.rimm   = mem_wb.wimm;
			mem_wb.rshamt = mem_wb.wshamt;
			mem_wb.ritype = mem_wb.witype;

			if_id.rWriteData  = if_id.wWriteData ;
			id_ex.rWriteData  = id_ex.wWriteData ;
			ex_mem.rWriteData  = ex_mem.wWriteData ;
			mem_wb.rWriteData  = mem_wb.wWriteData ;
			if_id.rRsData= if_id.wRsData;
			id_ex.rRtData= id_ex.wRtData;
			ex_mem.rRrData= ex_mem.wRrData;
			mem_wb.rRdData= mem_wb.wRdData;
			if_id.renable= if_id.wenable;
			id_ex.renable= id_ex.wenable;
			ex_mem.renable= ex_mem.wenable;
			mem_wb.renable= mem_wb.wenable;
			if_id.risRt= if_id.wisRt;
			id_ex.risRt= id_ex.wisRt;
			ex_mem.risRt= ex_mem.wisRt;
			mem_wb.risRt= mem_wb.wisRt;
						print_regs();
						// for(i=0; i<5;i++){
						// 	printf("Mem[%d] : %d\n",i+268500992, memory[i] );
						// }
						// printf("\n\n\n");
				
				if(rpc>=nInstr){
					endIns++;
					continue;
				} else{
					endIns = 0;
				}
			}
			// if(endIns == 1){
			if(r_pc==nInstr+1){
				// printf("LAST STAGE1\n");
	   			   	pthread_create(&ex,&attr,ex_ins,(void*)&instructions[rpc-1]);
	   				pthread_create(&mem,&attr,mem_ins,(void*)&instructions[rpc-2]);
	   				pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[rpc-3]);
	   			
	   				pthread_join(ex,NULL);
					pthread_join(mem,NULL);
					pthread_join(wb,NULL);

					fp1 = fopen("./svg/procfinal345.svg","r");
	   			   	fp2 = fopen(svg_file,"w");
	   			   	while(1)
	   			   	{
	   			   		ch = fgetc(fp1);
	   			   		if(ch == EOF)
	   			   			break;
	   			   		else
	   			   			putc(ch,fp2);
	   			   	}
	   			   	// printf("#######################################################################File copied Successfully!");
   					fclose(fp1);
   					fclose(fp2);


   	char buff[BUFSIZ];      // the input line
    char newbuff[BUFSIZ];   // the results of any editing
    //printf("ttttttttttttttttttt%s\n",instructions[0].ins_name);
    char findme[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>";
    char replacewith1[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith2[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith3[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith4[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith5[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    FILE *in, *out;
    int flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );

    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">********</tspan></text>");
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">********</tspan></text>");
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
           fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>",instructions[rpc-1].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>",instructions[rpc-2].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

    flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>",instructions[rpc-3].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );

    remove(svg_file);
    rename("replica.svg",svg_file);

					nCycle++;
					w_pc++;


					rpc = wpc;
					r_pc = w_pc;
					// if(ex_mem.wCond == 1){
					// 	w_pc = wpc;
					// }
					registers[34] = wpc;
			if_id.rPCSrc     = if_id.wPCSrc    ;   					
			if_id.rRegWrite  = if_id.wRegWrite ;   	
			if_id.rALUSrc    = if_id.wALUSrc   ;  		  
			if_id.rALUOp     = if_id.wALUOp    ; 					
			if_id.rRegDst    = if_id.wRegDst   ; 		  
			if_id.rbranch    = if_id.wbranch   ;				
			if_id.rMemRead   = if_id.wMemRead  ;	 
			if_id.rMemWrite  = if_id.wMemWrite ; 	
			if_id.rMemtoReg  = if_id.wMemtoReg ; 	
			if_id.rRs        = if_id.wRs       ; 	     
			if_id.rRt        = if_id.wRt       ; 	    
			if_id.rRd        = if_id.wRd       ;   
			if_id.rALUResult = if_id.wALUResult;
			if_id.rMultResult = if_id.wMultResult;	
			if_id.rAddResult = if_id.wAddResult;	
			if_id.rReadAdd   = if_id.wReadAdd  ;		
			if_id.rWriteAdd  = if_id.wWriteAdd ;				
			if_id.rCond      = if_id.wCond     ;				
			if_id.rReadData  = if_id.wReadData ;
			if_id.rReadMultData = if_id.wReadMultData;
			if_id.rrr    = if_id.wrr;
			if_id.rimm   = if_id.wimm;
			if_id.rshamt = if_id.wshamt;
			if_id.ritype = if_id.witype;

			id_ex.rPCSrc     = id_ex.wPCSrc    ;
			id_ex.rRegWrite  = id_ex.wRegWrite ;
			id_ex.rALUSrc    = id_ex.wALUSrc   ;
			id_ex.rALUOp     = id_ex.wALUOp    ;
			id_ex.rRegDst    = id_ex.wRegDst   ;
			id_ex.rbranch    = id_ex.wbranch   ;
			id_ex.rMemRead   = id_ex.wMemRead  ;
			id_ex.rMemWrite  = id_ex.wMemWrite ;
			id_ex.rMemtoReg  = id_ex.wMemtoReg ;
			id_ex.rRs        = id_ex.wRs       ;
			id_ex.rRt        = id_ex.wRt       ;
			id_ex.rRd        = id_ex.wRd       ;
			id_ex.rALUResult = id_ex.wALUResult;
			id_ex.rMultResult = id_ex.wMultResult;
			id_ex.rAddResult = id_ex.wAddResult;
			id_ex.rReadAdd   = id_ex.wReadAdd  ;
			id_ex.rWriteAdd  = id_ex.wWriteAdd ;
			id_ex.rCond      = id_ex.wCond     ;
			id_ex.rReadData  = id_ex.wReadData ;
			id_ex.rReadMultData = id_ex.wReadMultData;
			id_ex.rrr    = id_ex.wrr;
			id_ex.rimm   = id_ex.wimm;
			id_ex.rshamt = id_ex.wshamt;
			id_ex.ritype = id_ex.witype;

			ex_mem.rPCSrc     = ex_mem.wPCSrc    ;
			ex_mem.rRegWrite  = ex_mem.wRegWrite ;
			ex_mem.rALUSrc    = ex_mem.wALUSrc   ;
			ex_mem.rALUOp     = ex_mem.wALUOp    ;
			ex_mem.rRegDst    = ex_mem.wRegDst   ;
			ex_mem.rbranch    = ex_mem.wbranch   ;
			ex_mem.rMemRead   = ex_mem.wMemRead  ;
			ex_mem.rMemWrite  = ex_mem.wMemWrite ;
			ex_mem.rMemtoReg  = ex_mem.wMemtoReg ;
			ex_mem.rRs        = ex_mem.wRs       ;
			ex_mem.rRt        = ex_mem.wRt       ;
			ex_mem.rRd        = ex_mem.wRd       ;
			ex_mem.rALUResult = ex_mem.wALUResult;
			ex_mem.rMultResult = ex_mem.wMultResult;
			ex_mem.rAddResult = ex_mem.wAddResult;
			ex_mem.rReadAdd   = ex_mem.wReadAdd  ;
			ex_mem.rWriteAdd  = ex_mem.wWriteAdd ;
			ex_mem.rCond      = ex_mem.wCond     ;
			ex_mem.rReadData  = ex_mem.wReadData ;
			ex_mem.rReadMultData = ex_mem.wReadMultData;
			ex_mem.rrr    = ex_mem.wrr;
			ex_mem.rimm   = ex_mem.wimm;
			ex_mem.rshamt = ex_mem.wshamt;
			ex_mem.ritype = ex_mem.witype;

			mem_wb.rPCSrc     = mem_wb.wPCSrc    ;
			mem_wb.rRegWrite  = mem_wb.wRegWrite ;
			mem_wb.rALUSrc    = mem_wb.wALUSrc   ;
			mem_wb.rALUOp     = mem_wb.wALUOp    ;
			mem_wb.rRegDst    = mem_wb.wRegDst   ;
			mem_wb.rbranch    = mem_wb.wbranch   ;
			mem_wb.rMemRead   = mem_wb.wMemRead  ;
			mem_wb.rMemWrite  = mem_wb.wMemWrite ;
			mem_wb.rMemtoReg  = mem_wb.wMemtoReg ;
			mem_wb.rRs        = mem_wb.wRs       ;
			mem_wb.rRt        = mem_wb.wRt       ;
			mem_wb.rRd        = mem_wb.wRd       ;
			mem_wb.rALUResult = mem_wb.wALUResult;
			mem_wb.rMultResult = mem_wb.wMultResult;
			mem_wb.rAddResult = mem_wb.wAddResult;
			mem_wb.rReadAdd   = mem_wb.wReadAdd  ;
			mem_wb.rWriteAdd  = mem_wb.wWriteAdd ;
			mem_wb.rCond      = mem_wb.wCond     ;
			mem_wb.rReadData  = mem_wb.wReadData ;
			mem_wb.rReadMultData = mem_wb.wReadMultData;
			mem_wb.rrr    = mem_wb.wrr;
			mem_wb.rimm   = mem_wb.wimm;
			mem_wb.rshamt = mem_wb.wshamt;
			mem_wb.ritype = mem_wb.witype;

			if_id.rWriteData  = if_id.wWriteData ;
			id_ex.rWriteData  = id_ex.wWriteData ;
			ex_mem.rWriteData  = ex_mem.wWriteData ;
			mem_wb.rWriteData  = mem_wb.wWriteData ;
			if_id.rRsData= if_id.wRsData;
			id_ex.rRtData= id_ex.wRtData;
			ex_mem.rRrData= ex_mem.wRrData;
			mem_wb.rRdData= mem_wb.wRdData;
			if_id.renable= if_id.wenable;
			id_ex.renable= id_ex.wenable;
			ex_mem.renable= ex_mem.wenable;
			mem_wb.renable= mem_wb.wenable;
			if_id.risRt= if_id.wisRt;
			id_ex.risRt= id_ex.wisRt;
			ex_mem.risRt= ex_mem.wisRt;
			mem_wb.risRt= mem_wb.wisRt;
					print_regs();
					// for(i=0; i<5;i++){
					// 	printf("Mem[%d] : %d\n",i+268500992, memory[i] );
					// }
					// printf("\n\n\n");

				if(rpc>=nInstr){
					endIns++;
					continue;
				} else{
					endIns = 0;
				}
			}

			// if(endIns == 2){
			if(r_pc==nInstr+2){
				// printf("LAST STAGE2\n");
	   				pthread_create(&mem,&attr,mem_ins,(void*)&instructions[rpc-1]);
	   				pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[rpc-2]);

					pthread_join(mem,NULL);
					pthread_join(wb,NULL);


	   				fp1 = fopen("./svg/procfinal45.svg","r");
	   			   	fp2 = fopen(svg_file,"w");
	   			   	while(1)
	   			   	{
	   			   		ch = fgetc(fp1);
	   			   		if(ch == EOF)
	   			   			break;
	   			   		else
	   			   			putc(ch,fp2);
	   			   	}
	   			   	// printf("#######################################################################File copied Successfully!");
   					fclose(fp1);
   					fclose(fp2);

   						char buff[BUFSIZ];      // the input line
    char newbuff[BUFSIZ];   // the results of any editing
    //printf("ttttttttttttttttttt%s\n",instructions[0].ins_name);
    char findme[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>";
    char replacewith1[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith2[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith3[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith4[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith5[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    FILE *in, *out;
    int flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );

    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
           fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">********</tspan></text>");
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
           fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">********</tspan></text>");
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
           fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">********</tspan></text>");
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>",instructions[rpc-1].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>",instructions[rpc-2].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
//yo
    remove(svg_file);
    rename("replica.svg",svg_file);
	   				nCycle++;
	   				w_pc++;
	   				rpc = wpc;
	   				r_pc = w_pc;
	   				registers[34] = wpc;
			if_id.rPCSrc     = if_id.wPCSrc    ;   					
			if_id.rRegWrite  = if_id.wRegWrite ;   	
			if_id.rALUSrc    = if_id.wALUSrc   ;  		  
			if_id.rALUOp     = if_id.wALUOp    ; 					
			if_id.rRegDst    = if_id.wRegDst   ; 		  
			if_id.rbranch    = if_id.wbranch   ;				
			if_id.rMemRead   = if_id.wMemRead  ;	 
			if_id.rMemWrite  = if_id.wMemWrite ; 	
			if_id.rMemtoReg  = if_id.wMemtoReg ; 	
			if_id.rRs        = if_id.wRs       ; 	     
			if_id.rRt        = if_id.wRt       ; 	    
			if_id.rRd        = if_id.wRd       ;   
			if_id.rALUResult = if_id.wALUResult;
			if_id.rMultResult = if_id.wMultResult;	
			if_id.rAddResult = if_id.wAddResult;	
			if_id.rReadAdd   = if_id.wReadAdd  ;		
			if_id.rWriteAdd  = if_id.wWriteAdd ;				
			if_id.rCond      = if_id.wCond     ;				
			if_id.rReadData  = if_id.wReadData ;
			if_id.rReadMultData = if_id.wReadMultData;
			if_id.rrr    = if_id.wrr;
			if_id.rimm   = if_id.wimm;
			if_id.rshamt = if_id.wshamt;
			if_id.ritype = if_id.witype;

			id_ex.rPCSrc     = id_ex.wPCSrc    ;
			id_ex.rRegWrite  = id_ex.wRegWrite ;
			id_ex.rALUSrc    = id_ex.wALUSrc   ;
			id_ex.rALUOp     = id_ex.wALUOp    ;
			id_ex.rRegDst    = id_ex.wRegDst   ;
			id_ex.rbranch    = id_ex.wbranch   ;
			id_ex.rMemRead   = id_ex.wMemRead  ;
			id_ex.rMemWrite  = id_ex.wMemWrite ;
			id_ex.rMemtoReg  = id_ex.wMemtoReg ;
			id_ex.rRs        = id_ex.wRs       ;
			id_ex.rRt        = id_ex.wRt       ;
			id_ex.rRd        = id_ex.wRd       ;
			id_ex.rALUResult = id_ex.wALUResult;
			id_ex.rMultResult = id_ex.wMultResult;
			id_ex.rAddResult = id_ex.wAddResult;
			id_ex.rReadAdd   = id_ex.wReadAdd  ;
			id_ex.rWriteAdd  = id_ex.wWriteAdd ;
			id_ex.rCond      = id_ex.wCond     ;
			id_ex.rReadData  = id_ex.wReadData ;
			id_ex.rReadMultData = id_ex.wReadMultData;
			id_ex.rrr    = id_ex.wrr;
			id_ex.rimm   = id_ex.wimm;
			id_ex.rshamt = id_ex.wshamt;
			id_ex.ritype = id_ex.witype;

			ex_mem.rPCSrc     = ex_mem.wPCSrc    ;
			ex_mem.rRegWrite  = ex_mem.wRegWrite ;
			ex_mem.rALUSrc    = ex_mem.wALUSrc   ;
			ex_mem.rALUOp     = ex_mem.wALUOp    ;
			ex_mem.rRegDst    = ex_mem.wRegDst   ;
			ex_mem.rbranch    = ex_mem.wbranch   ;
			ex_mem.rMemRead   = ex_mem.wMemRead  ;
			ex_mem.rMemWrite  = ex_mem.wMemWrite ;
			ex_mem.rMemtoReg  = ex_mem.wMemtoReg ;
			ex_mem.rRs        = ex_mem.wRs       ;
			ex_mem.rRt        = ex_mem.wRt       ;
			ex_mem.rRd        = ex_mem.wRd       ;
			ex_mem.rALUResult = ex_mem.wALUResult;
			ex_mem.rMultResult = ex_mem.wMultResult;
			ex_mem.rAddResult = ex_mem.wAddResult;
			ex_mem.rReadAdd   = ex_mem.wReadAdd  ;
			ex_mem.rWriteAdd  = ex_mem.wWriteAdd ;
			ex_mem.rCond      = ex_mem.wCond     ;
			ex_mem.rReadData  = ex_mem.wReadData ;
			ex_mem.rReadMultData = ex_mem.wReadMultData;
			ex_mem.rrr    = ex_mem.wrr;
			ex_mem.rimm   = ex_mem.wimm;
			ex_mem.rshamt = ex_mem.wshamt;
			ex_mem.ritype = ex_mem.witype;

			mem_wb.rPCSrc     = mem_wb.wPCSrc    ;
			mem_wb.rRegWrite  = mem_wb.wRegWrite ;
			mem_wb.rALUSrc    = mem_wb.wALUSrc   ;
			mem_wb.rALUOp     = mem_wb.wALUOp    ;
			mem_wb.rRegDst    = mem_wb.wRegDst   ;
			mem_wb.rbranch    = mem_wb.wbranch   ;
			mem_wb.rMemRead   = mem_wb.wMemRead  ;
			mem_wb.rMemWrite  = mem_wb.wMemWrite ;
			mem_wb.rMemtoReg  = mem_wb.wMemtoReg ;
			mem_wb.rRs        = mem_wb.wRs       ;
			mem_wb.rRt        = mem_wb.wRt       ;
			mem_wb.rRd        = mem_wb.wRd       ;
			mem_wb.rALUResult = mem_wb.wALUResult;
			mem_wb.rMultResult = mem_wb.wMultResult;
			mem_wb.rAddResult = mem_wb.wAddResult;
			mem_wb.rReadAdd   = mem_wb.wReadAdd  ;
			mem_wb.rWriteAdd  = mem_wb.wWriteAdd ;
			mem_wb.rCond      = mem_wb.wCond     ;
			mem_wb.rReadData  = mem_wb.wReadData ;
			mem_wb.rReadMultData = mem_wb.wReadMultData;
			mem_wb.rrr    = mem_wb.wrr;
			mem_wb.rimm   = mem_wb.wimm;
			mem_wb.rshamt = mem_wb.wshamt;
			mem_wb.ritype = mem_wb.witype;

			if_id.rWriteData  = if_id.wWriteData ;
			id_ex.rWriteData  = id_ex.wWriteData ;
			ex_mem.rWriteData  = ex_mem.wWriteData ;
			mem_wb.rWriteData  = mem_wb.wWriteData ;
			if_id.rRsData= if_id.wRsData;
			id_ex.rRtData= id_ex.wRtData;
			ex_mem.rRrData= ex_mem.wRrData;
			mem_wb.rRdData= mem_wb.wRdData;
			if_id.renable= if_id.wenable;
			id_ex.renable= id_ex.wenable;
			ex_mem.renable= ex_mem.wenable;
			mem_wb.renable= mem_wb.wenable;
			if_id.risRt= if_id.wisRt;
			id_ex.risRt= id_ex.wisRt;
			ex_mem.risRt= ex_mem.wisRt;
			mem_wb.risRt= mem_wb.wisRt;
					print_regs();
					// for(i=0; i<5;i++){
					// 	printf("Mem[%d] : %d\n",i+268500992, memory[i] );
					// }
					// printf("\n\n\n");

				if(rpc>=nInstr){
					endIns++;
					continue;
				} else{
					endIns = 0;
				}
			}

			// if(endIns == 3){
			if(r_pc==nInstr+3){
				// printf("LAST STAGE3\n");
				   	pthread_create(&wb,&attr,write_back_ins,(void*)&instructions[rpc-1]);

					pthread_join(wb,NULL);

					fp1 = fopen("./svg/procfinal5.svg","r");
	   			   	fp2 = fopen(svg_file,"w");
	   			   	while(1)
	   			   	{
	   			   		ch = fgetc(fp1);
	   			   		if(ch == EOF)
	   			   			break;
	   			   		else
	   			   			putc(ch,fp2);
	   			   	}
	   			   	// printf("#######################################################################File copied Successfully!");
   					fclose(fp1);
   					fclose(fp2);

   					char buff[BUFSIZ];      // the input line
    char newbuff[BUFSIZ];   // the results of any editing
    //printf("ttttttttttttttttttt%s\n",instructions[0].ins_name);
    char findme[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>";
    char replacewith1[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith2[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith3[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith4[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    char replacewith5[] = "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">--------</tspan></text>\n";
    FILE *in, *out;
    int flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );

    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">********</tspan></text>");
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">********</tspan></text>");
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
    fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

        flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">********</tspan></text>");
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">********</tspan></text>");
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );
    remove(svg_file);
    rename("replica.svg",svg_file);

            flag=0;
    in = fopen( svg_file, "r" );
    out= fopen( "replica.svg", "w" );
    while ( fgets( buff, BUFSIZ, in ) != NULL ) {
        if ( strstr( buff, findme ) != NULL && (flag==0)) {
            strcpy(newbuff,replacewith1);
            flag=1;
            fprintf( out , "         style=\"font-size:4.01269484px;line-height:1;stroke-width:0.20063476px\">%s</tspan></text>",instructions[rpc-1].ins_name );
        } else {
            strcpy( newbuff, buff );
            fputs( newbuff, out );
        }
        
    }
        fclose( in );
    fclose( out );

    remove(svg_file);
    rename("replica.svg",svg_file);
					nCycle++;
					w_pc++;
					rpc = wpc;
					r_pc = w_pc;
					registers[34] = wpc;
			if_id.rPCSrc     = if_id.wPCSrc    ;   					
			if_id.rRegWrite  = if_id.wRegWrite ;   	
			if_id.rALUSrc    = if_id.wALUSrc   ;  		  
			if_id.rALUOp     = if_id.wALUOp    ; 					
			if_id.rRegDst    = if_id.wRegDst   ; 		  
			if_id.rbranch    = if_id.wbranch   ;				
			if_id.rMemRead   = if_id.wMemRead  ;	 
			if_id.rMemWrite  = if_id.wMemWrite ; 	
			if_id.rMemtoReg  = if_id.wMemtoReg ; 	
			if_id.rRs        = if_id.wRs       ; 	     
			if_id.rRt        = if_id.wRt       ; 	    
			if_id.rRd        = if_id.wRd       ;   
			if_id.rALUResult = if_id.wALUResult;
			if_id.rMultResult = if_id.wMultResult;	
			if_id.rAddResult = if_id.wAddResult;	
			if_id.rReadAdd   = if_id.wReadAdd  ;		
			if_id.rWriteAdd  = if_id.wWriteAdd ;				
			if_id.rCond      = if_id.wCond     ;				
			if_id.rReadData  = if_id.wReadData ;
			if_id.rReadMultData = if_id.wReadMultData;
			if_id.rrr    = if_id.wrr;
			if_id.rimm   = if_id.wimm;
			if_id.rshamt = if_id.wshamt;
			if_id.ritype = if_id.witype;

			id_ex.rPCSrc     = id_ex.wPCSrc    ;
			id_ex.rRegWrite  = id_ex.wRegWrite ;
			id_ex.rALUSrc    = id_ex.wALUSrc   ;
			id_ex.rALUOp     = id_ex.wALUOp    ;
			id_ex.rRegDst    = id_ex.wRegDst   ;
			id_ex.rbranch    = id_ex.wbranch   ;
			id_ex.rMemRead   = id_ex.wMemRead  ;
			id_ex.rMemWrite  = id_ex.wMemWrite ;
			id_ex.rMemtoReg  = id_ex.wMemtoReg ;
			id_ex.rRs        = id_ex.wRs       ;
			id_ex.rRt        = id_ex.wRt       ;
			id_ex.rRd        = id_ex.wRd       ;
			id_ex.rALUResult = id_ex.wALUResult;
			id_ex.rMultResult = id_ex.wMultResult;
			id_ex.rAddResult = id_ex.wAddResult;
			id_ex.rReadAdd   = id_ex.wReadAdd  ;
			id_ex.rWriteAdd  = id_ex.wWriteAdd ;
			id_ex.rCond      = id_ex.wCond     ;
			id_ex.rReadData  = id_ex.wReadData ;
			id_ex.rReadMultData = id_ex.wReadMultData;
			id_ex.rrr    = id_ex.wrr;
			id_ex.rimm   = id_ex.wimm;
			id_ex.rshamt = id_ex.wshamt;
			id_ex.ritype = id_ex.witype;

			ex_mem.rPCSrc     = ex_mem.wPCSrc    ;
			ex_mem.rRegWrite  = ex_mem.wRegWrite ;
			ex_mem.rALUSrc    = ex_mem.wALUSrc   ;
			ex_mem.rALUOp     = ex_mem.wALUOp    ;
			ex_mem.rRegDst    = ex_mem.wRegDst   ;
			ex_mem.rbranch    = ex_mem.wbranch   ;
			ex_mem.rMemRead   = ex_mem.wMemRead  ;
			ex_mem.rMemWrite  = ex_mem.wMemWrite ;
			ex_mem.rMemtoReg  = ex_mem.wMemtoReg ;
			ex_mem.rRs        = ex_mem.wRs       ;
			ex_mem.rRt        = ex_mem.wRt       ;
			ex_mem.rRd        = ex_mem.wRd       ;
			ex_mem.rALUResult = ex_mem.wALUResult;
			ex_mem.rMultResult = ex_mem.wMultResult;
			ex_mem.rAddResult = ex_mem.wAddResult;
			ex_mem.rReadAdd   = ex_mem.wReadAdd  ;
			ex_mem.rWriteAdd  = ex_mem.wWriteAdd ;
			ex_mem.rCond      = ex_mem.wCond     ;
			ex_mem.rReadData  = ex_mem.wReadData ;
			ex_mem.rReadMultData = ex_mem.wReadMultData;
			ex_mem.rrr    = ex_mem.wrr;
			ex_mem.rimm   = ex_mem.wimm;
			ex_mem.rshamt = ex_mem.wshamt;
			ex_mem.ritype = ex_mem.witype;

			mem_wb.rPCSrc     = mem_wb.wPCSrc    ;
			mem_wb.rRegWrite  = mem_wb.wRegWrite ;
			mem_wb.rALUSrc    = mem_wb.wALUSrc   ;
			mem_wb.rALUOp     = mem_wb.wALUOp    ;
			mem_wb.rRegDst    = mem_wb.wRegDst   ;
			mem_wb.rbranch    = mem_wb.wbranch   ;
			mem_wb.rMemRead   = mem_wb.wMemRead  ;
			mem_wb.rMemWrite  = mem_wb.wMemWrite ;
			mem_wb.rMemtoReg  = mem_wb.wMemtoReg ;
			mem_wb.rRs        = mem_wb.wRs       ;
			mem_wb.rRt        = mem_wb.wRt       ;
			mem_wb.rRd        = mem_wb.wRd       ;
			mem_wb.rALUResult = mem_wb.wALUResult;
			mem_wb.rMultResult = mem_wb.wMultResult;
			mem_wb.rAddResult = mem_wb.wAddResult;
			mem_wb.rReadAdd   = mem_wb.wReadAdd  ;
			mem_wb.rWriteAdd  = mem_wb.wWriteAdd ;
			mem_wb.rCond      = mem_wb.wCond     ;
			mem_wb.rReadData  = mem_wb.wReadData ;
			mem_wb.rReadMultData = mem_wb.wReadMultData;
			mem_wb.rrr    = mem_wb.wrr;
			mem_wb.rimm   = mem_wb.wimm;
			mem_wb.rshamt = mem_wb.wshamt;
			mem_wb.ritype = mem_wb.witype;

			if_id.rWriteData  = if_id.wWriteData ;
			id_ex.rWriteData  = id_ex.wWriteData ;
			ex_mem.rWriteData  = ex_mem.wWriteData ;
			mem_wb.rWriteData  = mem_wb.wWriteData ;
			if_id.rRsData= if_id.wRsData;
			id_ex.rRtData= id_ex.wRtData;
			ex_mem.rRrData= ex_mem.wRrData;
			mem_wb.rRdData= mem_wb.wRdData;
			if_id.renable= if_id.wenable;
			id_ex.renable= id_ex.wenable;
			ex_mem.renable= ex_mem.wenable;
			mem_wb.renable= mem_wb.wenable;
			if_id.risRt= if_id.wisRt;
			id_ex.risRt= id_ex.wisRt;
			ex_mem.risRt= ex_mem.wisRt;
			mem_wb.risRt= mem_wb.wisRt;

					print_regs();
					// for(i=0; i<5;i++){
					// 	printf("Mem[%d] : %d\n",i+268500992, memory[i] );
					// }
					// printf("\n\n\n");


				// printf("REACHED END\n");
				// if(rpc>= nInstr){
				// 	printf("BREAKING OUT!!!\n");
				// 	break;
				// }
			}

			if(w_pc>nInstr + 3){
				// printf("REACHED END\n");
				// // if(rpc>= nInstr){
				// printf("BREAKING OUT!!!\n");
				break;
				// }
			}
		}
	}

   	}

   	fclose(trace);
   	trace = fopen("trace.trace","r");
   	

   	init_cache();
   	play_trace(trace);
   	// print_stats();

   	int Imiss = num_Imisses();
   	int Dmiss = num_Dmisses();
   	int miss = Imiss + Dmiss;
   	nCycle += latency * miss;
   	nIdle += latency * miss;

   	// printf("%f\n", frequency);
	FILE* outres = 	fopen(argv[4], "w");
	fprintf(outres, "Instructions,%d\n",nIexe );
	fprintf(outres, "Cycles,%d\n",nCycle ); //CHANGE
	fprintf(outres, "IPC,%.4f\n",(1.0*nIexe)/(1.0*nCycle) );
	fprintf(outres, "Time (ns),%.4f\n",1.0*nCycle/2.0 ); 
	fprintf(outres, "Idle time,%.4f\n",1.0*nIdle/2.0 ); //CHANGE
	fprintf(outres, "Idle time (%%),%.4f%%\n",(1.0*nIdle)/(1.0*nCycle)*100 );
	fprintf(outres, "Cache Summary\n");
	fprintf(outres, "Cache L1-I\n");
	fprintf(outres, "num cache accesses,%d\n",nIcache ); //CHANGE
	fprintf(outres, "num cache misses,%d\n",Imiss );
	fprintf(outres, "miss rate,%.4f\n", (1.0*Imiss)/(1.0*nIcache)*100);
	fprintf(outres, "Cache L1-D\n");
	fprintf(outres, "num cache accesses,%d\n",nDcache ); //CHANGE
	fprintf(outres, "num cache misses,%d\n",Dmiss );
	fprintf(outres, "miss rate,%.4f\n", (1.0*Dmiss)/(1.0*nDcache)*100);
	fprintf(outres, "DRAM summary\n" );
	fprintf(outres, "num dram accesses\n",nDcache + nIcache );
	fprintf(outres, "average dram latency (ns),%.4f\n", (latency*miss)/((nIcache + nDcache)* frequency));
	fclose(outres);
}
