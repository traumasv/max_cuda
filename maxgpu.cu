#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <cuda.h>

unsigned int getmaxcu(unsigned int *, unsigned int);

int main(int argc, char *argv[])
{
    unsigned int size = 0;  // The size of the array
    unsigned int i;  // loop index
    unsigned int * numbers; //pointer to the array

    if(argc !=2)
    {
       printf("usage: maxseq num\n");
       printf("num = size of the array\n");
       exit(1);
    }
   
    size = atol(argv[1]);

    numbers = (unsigned int *) malloc(size * sizeof(unsigned int));
    if( !numbers )
    {
       printf("Unable to allocate mem for an array of size %u\n", size);
       exit(1);
    }    

    srand(time(NULL)); // setting a seed for the random number generator
    // Fill-up the array with random numbers from 0 to size-1 
    for( i = 0; i < size; i++){
       numbers[i] = rand() % size;
       printf("%d\n", numbers[i]);
    }
    unsigned int max = getmaxcu(numbers, size);
    printf(" The maximum number in the array is: %u\n", max);
    free(numbers);
    exit(0);
}//end of main


/*
   input: pointer to an array of long int
          number of elements in the array
   output: the maximum number of the array
*/

__global__ void getmaxcu(unsigned int* globalInputArr, unsigned int* globalOutputArr, unsigned int* sizeArr){
	//you need a shared array (per block) to put the block's max into
	//you also need a global array to put the overall max into
	extern __shared__ unsigned int sdata[];

	unsigned int size = sizeArr[0];

	unsigned int tid = threadIdx.x; 
	unsigned int gid = (blockIdx.x * blockDim.x) + threadIdx.x; //getting the unique index of thread
	sdata[tid] = 0; //initializing the shared data array (shared per block)
	
	if(gid < size){
		sdata[tid] = globalInputArr[gid];
	}
	__syncthreads();
	/*
	for (unsigned int s = blockDim.x/2; s>0; s>>=1) {
		if(gid < size && tid < s) {
			sdata[tid] = max(sdata[tid], sdata[tid + s]);
		}
		__syncthreads();
	}
	*/
	if (tid == 0){
		globalOutputArr[blockIdx.x] = sdata[tid]; //putting all the max from each block into a global output array
	}
}

__global__ void finalmaxcu(unsigned int* globalOutputArr, unsigned int* max){
	int tid = threadIdx.x;
	extern __shared__ unsigned int sdata[];
	sdata[tid] = 0;

	if(tid < blockDim.x){
		sdata[tid] = globalOutputArr[tid];
	}
	__syncthreads();
	/*
	for (unsigned int s=blockDim.x/2; s>0; s>>=1){ //it starts at the half way mark and keeps div in 2
		if(tid < s){
			unsigned int greater = sdata[tid];
			if(sdata[tid] < sdata[tid+s]){
				greater = sdata[tid+s];
			}
			sdata[tid] = greater;
		}
		__syncthreads();
	}
	*/
	if (tid == 0){
		max[0] = sdata[tid];
	}
}

unsigned int getmaxcu(unsigned int* numbers, unsigned int num_elem){
	//max num of threads per SM : 2048
	//max num of threads per block : 1024

	unsigned int* sizeArr = (unsigned int*) malloc(sizeof(unsigned int));//creating an array to pass on to the device
	sizeArr[0] = num_elem;
	unsigned int* size; //declaring a size integer (device)
	cudaMalloc((void**)&size, sizeof(unsigned int)); 
	cudaMemcpy((void*) size, (void*) sizeArr, sizeof(unsigned int), cudaMemcpyHostToDevice);
	
	unsigned int* globalInputArr;
	cudaMalloc((void**)&globalInputArr, num_elem * sizeof(unsigned int));
	cudaMemcpy((void*) globalInputArr, (void*) numbers, num_elem * sizeof(unsigned int), cudaMemcpyHostToDevice);
	
	unsigned int* globalOutputArr;
	cudaMalloc((void**)&globalOutputArr, num_elem*sizeof(unsigned int));

	unsigned int* max;
	cudaMalloc((void**)&max, sizeof(unsigned int));//allocating the max number pointer in the device

	unsigned int* maxNum = (unsigned int*) malloc(sizeof(unsigned int)); //allocating the max number pointer in the host
	
	//first experimenting with block size of 128, the max block size is 1024
	//adding size as the third parameter in the triple bracket sets the byte size for the sdata (which is in the shared memory)
	//whatever is in sdata should be the size of N divided by the number of blocks (which is 8 for now)
	unsigned int sharedSize = (num_elem / 8) * sizeof(unsigned int);
	getmaxcu<<<8, 128, sharedSize>>>(globalInputArr, globalOutputArr, size); 

	unsigned int* copy = (unsigned int*) malloc(8 * sizeof(unsigned int));
	cudaMemcpy((void*) copy, (void*) globalOutputArr, (num_elem * sizeof(unsigned int)), cudaMemcpyDeviceToHost);
	for(int i = 0; i < 8; i++){
		printf("%u,",copy[i]);
	}

	printf("\n");
	finalmaxcu<<<1, 128, (8 * sizeof(unsigned int))>>>(globalOutputArr, max);
	cudaMemcpy((void*) maxNum, (void*) max, sizeof(unsigned int), cudaMemcpyDeviceToHost);//copying back the max from the device to host
   	
    cudaFree(max);
	cudaFree(globalInputArr);
	cudaFree(globalOutputArr);
	return maxNum[0];
}




unsigned int getmax(unsigned int num[], unsigned int size)
{

  unsigned int i;
  unsigned int max = num[0];

  for(i = 1; i < size; i++)
	if(num[i] > max)
	   max = num[i];

  return( max );

}