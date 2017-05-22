/*
 * cache.c
 */


#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#include "cache.h"
#include "main.h"

/* cache configuration parameters */
static int cache_split = 0;
static int cache_usize = DEFAULT_CACHE_SIZE;
static int cache_isize = DEFAULT_CACHE_SIZE; 
static int cache_dsize = DEFAULT_CACHE_SIZE;
static int cache_block_size = DEFAULT_CACHE_BLOCK_SIZE;
static int words_per_block = DEFAULT_CACHE_BLOCK_SIZE / WORD_SIZE;
static int cache_assoc = DEFAULT_CACHE_ASSOC;
static int cache_writeback = DEFAULT_CACHE_WRITEBACK;
static int cache_writealloc = DEFAULT_CACHE_WRITEALLOC;

int num_BLOCKS = DEFAULT_CACHE_SIZE/DEFAULT_CACHE_BLOCK_SIZE;
int num_WORDS = DEFAULT_CACHE_BLOCK_SIZE / 4;
// int TAG = 19;
// int INDEX = 9;
// int OFFSET = 4;

/* cache model data structures */
static Pcache icache;
static Pcache dcache;
static cache c1;
static cache c2;
static cache_stat cache_stat_inst;
static cache_stat cache_stat_data;

cache_line* blocks1;
cache_line* blocks2;

cache ucache;

/************************************************************/
void set_cache_param(param, value)
  int param;
  int value;
{

  switch (param) {
  case CACHE_PARAM_BLOCK_SIZE:
    cache_block_size = value;
    words_per_block = value / WORD_SIZE;
    break;
  case CACHE_PARAM_USIZE:
    cache_split = FALSE;
    cache_usize = value;
    break;
  case CACHE_PARAM_ISIZE:
    cache_split = TRUE;
    cache_isize = value;
    break;
  case CACHE_PARAM_DSIZE:
    cache_split = TRUE;
    cache_dsize = value;
    break;
  case CACHE_PARAM_ASSOC:
    cache_assoc = value;
    break;
  case CACHE_PARAM_WRITEBACK:
    cache_writeback = TRUE;
    break;
  case CACHE_PARAM_WRITETHROUGH:
    cache_writeback = FALSE;
    break;
  case CACHE_PARAM_WRITEALLOC:
    cache_writealloc = TRUE;
    break;
  case CACHE_PARAM_NOWRITEALLOC:
    cache_writealloc = FALSE;
    break;
  default:
    printf("error set_cache_param: bad parameter value\n");
    exit(-1);
  }

}
/************************************************************/

/************************************************************/
void init_cache()
{

  /* initialize the cache, and cache statistics data structures */
 
  if(!cache_split){
    num_BLOCKS = cache_usize/cache_block_size;
    num_WORDS = cache_block_size/4;
    // printf("num_WORDS %d\n",num_WORDS);
    int i=0;

    c1.size = cache_usize;
    c1.associativity = cache_assoc;
    // n_sets
    c1.index_mask_offset = LOG2(cache_block_size);
    c1.index_mask = (num_BLOCKS - 1) << c1.index_mask_offset;
    // printf("%d\n",num_BLOCKS );
    // printf("%d\n",num_WORDS );
    // printf("%d\n",c1.index_mask_offset );
    // printf("%08x\n",c1.index_mask );

    // c1->tag_mask_offset = LOG2(cache_usize);
   //    c1->tag_mask = (0xFFFFFFFF << (c1->tag_mask_offset));
    // LRU_head
    // LRU_tail
    c1.contents = 0;

    cache_stat_data.accesses = 0;     
    cache_stat_data.misses = 0;     
    cache_stat_data.replacements = 0;   
    cache_stat_data.demand_fetches = 0; 
    cache_stat_data.copies_back = 0;

    cache_stat_inst.accesses = 0;     
    cache_stat_inst.misses = 0;     
    cache_stat_inst.replacements = 0;   
    cache_stat_inst.demand_fetches = 0; 
    cache_stat_inst.copies_back = 0;


    blocks1 = (cache_line*) malloc(num_BLOCKS * sizeof(cache_line));
    for(i=0; i<num_BLOCKS; i++){
      blocks1[i].tag = 0;
      blocks1[i].dirty = 0;
      blocks1[i].valid = 0;
    }
  } else {
    num_BLOCKS = cache_isize/cache_block_size;
    num_WORDS = cache_block_size/4;
    // printf("num_WORDS %d\n",num_WORDS);
    int i=0;

    c1.size = cache_dsize;
    c1.associativity = 1;
    // n_sets
    c1.index_mask_offset = LOG2(cache_block_size);
    c1.index_mask = (num_BLOCKS - 1) << c1.index_mask_offset;
    // printf("%d\n",num_BLOCKS );
    // printf("%d\n",num_WORDS );
    // printf("%d\n",c1.index_mask_offset );
    // printf("%08x\n",c1.index_mask );

    // c1->tag_mask_offset = LOG2(cache_usize);
   //    c1->tag_mask = (0xFFFFFFFF << (c1->tag_mask_offset));
    // LRU_head
    // LRU_tail
    c1.contents = 0;

    cache_stat_data.accesses = 0;     
    cache_stat_data.misses = 0;     
    cache_stat_data.replacements = 0;   
    cache_stat_data.demand_fetches = 0; 
    cache_stat_data.copies_back = 0;

    cache_stat_inst.accesses = 0;     
    cache_stat_inst.misses = 0;     
    cache_stat_inst.replacements = 0;   
    cache_stat_inst.demand_fetches = 0; 
    cache_stat_inst.copies_back = 0;


    blocks1 = (cache_line*) malloc(num_BLOCKS * sizeof(cache_line));
    for(i=0; i<num_BLOCKS; i++){
      blocks1[i].tag = 0;
      blocks1[i].dirty = 0;
      blocks1[i].valid = 0;
    }

    // printf("num_WORDS %d\n",num_WORDS);

    c2.size = cache_isize;
    c2.associativity = cache_assoc;
    // n_sets
    c2.index_mask_offset = LOG2(cache_block_size);
    c2.index_mask = (num_BLOCKS - 1) << c2.index_mask_offset;
    // printf("%d\n",num_BLOCKS );
    // printf("%d\n",num_WORDS );
    // printf("%d\n",c1.index_mask_offset );
    // printf("%08x\n",c1.index_mask );

    // c1->tag_mask_offset = LOG2(cache_usize);
   //    c1->tag_mask = (0xFFFFFFFF << (c1->tag_mask_offset));
    // LRU_head
    // LRU_tail
    c2.contents = 0;

    cache_stat_data.accesses = 0;     
    cache_stat_data.misses = 0;     
    cache_stat_data.replacements = 0;   
    cache_stat_data.demand_fetches = 0; 
    cache_stat_data.copies_back = 0;

    cache_stat_inst.accesses = 0;     
    cache_stat_inst.misses = 0;     
    cache_stat_inst.replacements = 0;   
    cache_stat_inst.demand_fetches = 0; 
    cache_stat_inst.copies_back = 0;


    blocks2 = (cache_line*) malloc(num_BLOCKS * sizeof(cache_line));
    for(i=0; i<num_BLOCKS; i++){
      blocks2[i].tag = 0;
      blocks2[i].dirty = 0;
      blocks2[i].valid = 0;
    }
  }
}
/************************************************************/

/************************************************************/
void perform_access(addr, access_type)
  unsigned addr, access_type;
{

  /* handle an access to the cache */
    
  if(!cache_split){
    int index = (addr & c1.index_mask) >> c1.index_mask_offset;
    int tag = addr >> LOG2(cache_usize);
    printf("PERFORMING ACCESS type: %d, %x\n",access_type, addr );
    // printf("%d\n", index);
    // printf("%d\n", blocks1[index].valid);
    // printf("%d\n", tag);
    // printf("%d\n", blocks1[index].tag);
    // printf("%d\n", blocks1[index].dirty);
    switch(access_type){    
      case 0: //Data Load
        cache_stat_data.accesses++;
        if((blocks1[index].valid == 1) && (blocks1[index].tag == tag)){
          //HIT
        } else { 
          //MISS
          // printf("MISS0\n");
          cache_stat_data.demand_fetches += num_WORDS;
          cache_stat_data.misses++;
          if(blocks1[index].valid == 1){
            cache_stat_data.replacements += 1;
          }
          if((cache_writeback == TRUE) && (blocks1[index].dirty == 1)){
            blocks1[index].dirty = 0;
            // cache_stat_data.demand_fetches += num_WORDS;
            cache_stat_data.copies_back += num_WORDS;
            // printf("copy1\n");
          }
          blocks1[index].valid = 1;
          blocks1[index].tag = tag;
        }
        break;

      case 1: //Data Store
        cache_stat_data.accesses++;

        if((blocks1[index].valid == 1) && (blocks1[index].tag == tag)){
          if(cache_writeback == FALSE){
            cache_stat_data.copies_back += num_WORDS;
            // printf("copy2\n");
          }
          blocks1[index].dirty = 1;

        } else {
          // printf("MISS1\n");
          cache_stat_data.misses++;
          cache_stat_data.demand_fetches += num_WORDS;
          if((cache_writeback == TRUE)){ //if wb then write if dirty
            // if(blocks1[index].valid == 0){
            //   cache_stat_data.copies_back += num_WORDS;
            // }

            if(blocks1[index].dirty == 1){
              cache_stat_data.replacements += 1;
              printf("replace3\n");
              blocks1[index].dirty = 1;
              cache_stat_data.copies_back += num_WORDS;
            }
          } else{
            cache_stat_data.copies_back += num_WORDS; //if wt always write back
            // printf("copy4\n");
          }
          blocks1[index].valid = 1;
          blocks1[index].tag = tag;
        }

        break;

      case 2: //Instr Load
        cache_stat_inst.accesses++;

        if((blocks1[index].valid == 1) && (blocks1[index].tag == tag)){

        } else {
          // printf("MISS2\n");
          // printf("%d\n",cache_writeback );
          // printf("%d\n",blocks1[index].dirty );
          cache_stat_inst.demand_fetches += num_WORDS;
          cache_stat_inst.misses++;
          if(blocks1[index].valid == 1){
            cache_stat_inst.replacements += 1;
          }
          if((cache_writeback == TRUE) && (blocks1[index].dirty == 1)){
            // printf("yay\n");
            blocks1[index].dirty = 0;
            // cache_stat_inst.demand_fetches += num_WORDS;
            
            cache_stat_inst.copies_back += num_WORDS;
            // printf("copy5\n");
          }
          blocks1[index].valid = 1;
          blocks1[index].tag = tag;
        }
        break;
    }
  } else {

    int index=-1, tag=-1;
    // printf("PERFORMING ACCESS type: %d, %x\n",access_type, addr );
    // printf("%d\n", index);
    // printf("%d\n", blocks1[index].valid);
    // printf("%d\n", tag);
    // printf("%d\n", blocks1[index].tag);
    // printf("%d\n", blocks1[index].dirty);
    switch(access_type){    
      case 0: //Data Load
        index = (addr & c1.index_mask) >> c1.index_mask_offset;
        tag = addr >> LOG2(cache_dsize);
        cache_stat_data.accesses++;
        if((blocks1[index].valid == 1) && (blocks1[index].tag == tag)){
          //HIT
        } else { 
          //MISS
          // printf("MISS0\n");
          cache_stat_data.demand_fetches += num_WORDS;
          cache_stat_data.misses++;
          if(blocks1[index].valid == 1){
            cache_stat_data.replacements += 1;
          }
          if((cache_writeback == TRUE) && (blocks1[index].dirty == 1)){
            blocks1[index].dirty = 0;
            // cache_stat_data.demand_fetches += num_WORDS;
            cache_stat_data.copies_back += num_WORDS;
            // printf("copy1\n");
          }
          blocks1[index].valid = 1;
          blocks1[index].tag = tag;
        }
        break;

      case 1: //Data Store
        index = (addr & c1.index_mask) >> c1.index_mask_offset;
        tag = addr >> LOG2(cache_dsize);
        cache_stat_data.accesses++;

        if((blocks1[index].valid == 1) && (blocks1[index].tag == tag)){
          if(cache_writeback == FALSE){
            cache_stat_data.copies_back += num_WORDS;
            // printf("copy2\n");
          }
          blocks1[index].dirty = 1;

        } else {
          // printf("MISS1\n");
          cache_stat_data.misses++;
          cache_stat_data.demand_fetches += num_WORDS;
          if((cache_writeback == TRUE)){ //if wb then write if dirty
            // if(blocks1[index].valid == 0){
            //   cache_stat_data.copies_back += num_WORDS;
            // }

            if(blocks1[index].dirty == 1){
              cache_stat_data.replacements += 1;
              printf("replace3\n");
              blocks1[index].dirty = 1;
              cache_stat_data.copies_back += num_WORDS;
            }
          } else{
            cache_stat_data.copies_back += num_WORDS; //if wt always write back
            // printf("copy4\n");
          }
          blocks1[index].valid = 1;
          blocks1[index].tag = tag;
        }

        break;

      case 2: //Instr Load
        index = (addr & c2.index_mask) >> c2.index_mask_offset;
        tag = addr >> LOG2(cache_isize);
        cache_stat_inst.accesses++;

        if((blocks2[index].valid == 1) && (blocks2[index].tag == tag)){

        } else {
          // printf("MISS2\n");
          // printf("%d\n",cache_writeback );
          // printf("%d\n",blocks1[index].dirty );
          cache_stat_inst.demand_fetches += num_WORDS;
          cache_stat_inst.misses++;
          if(blocks2[index].valid == 1){
            cache_stat_inst.replacements += 1;
          }
          if((cache_writeback == TRUE) && (blocks2[index].dirty == 1)){
            // printf("yay\n");
            blocks2[index].dirty = 0;
            // cache_stat_inst.demand_fetches += num_WORDS;
            
            cache_stat_inst.copies_back += num_WORDS;
            // printf("copy5\n");
          }
          blocks2[index].valid = 1;
          blocks2[index].tag = tag;
        }
        break;
    }
  

  }
  
}
/************************************************************/

/************************************************************/
void flush()
{

  /* flush the cache */
  int i=0;

  for(i=0; i<num_BLOCKS; i++){
    // printf("yaya\n");
    if(blocks1[i].dirty == 1){
      // printf("yaya\n");
      cache_stat_data.copies_back += num_WORDS;
    }
    blocks1[i].valid = 0;
    blocks1[i].dirty = 0;
  }

  for(i=0; i<num_BLOCKS; i++){
    // printf("yaya\n");
    if(blocks2[i].dirty == 1){
      // printf("yaya\n");
      cache_stat_inst.copies_back += num_WORDS;
    }
    blocks2[i].valid = 0;
    blocks2[i].dirty = 0;
  }
}
/************************************************************/

/************************************************************/
void delete(head, tail, item)
  Pcache_line *head, *tail;
  Pcache_line item;
{
  if (item->LRU_prev) {
    item->LRU_prev->LRU_next = item->LRU_next;
  } else {
    /* item at head */
    *head = item->LRU_next;
  }

  if (item->LRU_next) {
    item->LRU_next->LRU_prev = item->LRU_prev;
  } else {
    /* item at tail */
    *tail = item->LRU_prev;
  }
}
/************************************************************/

/************************************************************/
/* inserts at the head of the list */
void insert(head, tail, item)
  Pcache_line *head, *tail;
  Pcache_line item;
{
  item->LRU_next = *head;
  item->LRU_prev = (Pcache_line)NULL;

  if (item->LRU_next)
    item->LRU_next->LRU_prev = item;
  else
    *tail = item;

  *head = item;
}
/************************************************************/

/************************************************************/
void dump_settings()
{
  printf("*** CACHE SETTINGS ***\n");
  if (cache_split) {
    printf("  Split I- D-cache\n");
    printf("  I-cache size: \t%d\n", cache_isize);
    printf("  D-cache size: \t%d\n", cache_dsize);
  } else {
    printf("  Unified I- D-cache\n");
    printf("  Size: \t%d\n", cache_usize);
  }
  printf("  Associativity: \t%d\n", cache_assoc);
  printf("  Block size: \t%d\n", cache_block_size);
  printf("  Write policy: \t%s\n", 
   cache_writeback ? "WRITE BACK" : "WRITE THROUGH");
  printf("  Allocation policy: \t%s\n",
   cache_writealloc ? "WRITE ALLOCATE" : "WRITE NO ALLOCATE");
}
/************************************************************/

/************************************************************/
void print_stats()
{
  printf("\n*** CACHE STATISTICS ***\n");

  printf(" INSTRUCTIONS\n");
  printf("  accesses:  %d\n", cache_stat_inst.accesses);
  printf("  misses:    %d\n", cache_stat_inst.misses);
  if (!cache_stat_inst.accesses)
    printf("  miss rate: 0 (0)\n"); 
  else
    printf("  miss rate: %2.4f (hit rate %2.4f)\n", 
   (float)cache_stat_inst.misses / (float)cache_stat_inst.accesses,
   1.0 - (float)cache_stat_inst.misses / (float)cache_stat_inst.accesses);
  printf("  replace:   %d\n", cache_stat_inst.replacements);

  printf(" DATA\n");
  printf("  accesses:  %d\n", cache_stat_data.accesses);
  printf("  misses:    %d\n", cache_stat_data.misses);
  if (!cache_stat_data.accesses)
    printf("  miss rate: 0 (0)\n"); 
  else
    printf("  miss rate: %2.4f (hit rate %2.4f)\n", 
   (float)cache_stat_data.misses / (float)cache_stat_data.accesses,
   1.0 - (float)cache_stat_data.misses / (float)cache_stat_data.accesses);
  printf("  replace:   %d\n", cache_stat_data.replacements);

  printf(" TRAFFIC (in words)\n");
  printf("  demand fetch:  %d\n", cache_stat_inst.demand_fetches + 
   cache_stat_data.demand_fetches);
  printf("  copies back:   %d\n", cache_stat_inst.copies_back +
   cache_stat_data.copies_back);
}
/************************************************************/

int num_Imisses(){
  return cache_stat_inst.misses;
}

int num_Dmisses(){
  return cache_stat_data.misses;
}