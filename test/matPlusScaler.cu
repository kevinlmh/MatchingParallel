#include <stdio.h>
#include <stdlib.h>

#define BLOCK_SIZE 16

// Matrices are stored in row-major order:
// M(row, col) = *(M.elements + row * M.width + col)
typedef struct {
	int width;
	int height;
	double* elements;
} Matrix;

__global__
void matPlusScalerKernel(Matrix d_A, Matrix d_B, double C){
int row = blockIdx.y * blockDim.y + threadIdx.y;
	int col = blockIdx.x * blockDim.x + threadIdx.x;
	if(row > d_A.height || col > d_A.width) return;
	d_B.elements[row*d_A.width + col] = d_A.elements[row*d_A.width + col] + C;
}

void matPlusScaler(Matrix A, Matrix B, double C){

// load A, B, and C to device memory
	Matrix d_A;
	Matrix d_B;
	
	d_A.width = A.width;
	d_B.width = B.width;
	d_A.height = A.height;
	d_B.height = B.height;
	size_t size = A.width * A.height * sizeof(double);

	cudaError_t errA = cudaMalloc(&d_A.elements, size);
	printf("CUDA malloc A: %s\n", cudaGetErrorString(errA));
	cudaMemcpy(d_A.elements, A.elements, size, cudaMemcpyHostToDevice);
	printf("Copy A to device: %s\n", cudaGetErrorString(errA));

	cudaError_t errB = cudaMalloc(&d_B.elements, size);
	printf("CUDA malloc B: %s\n", cudaGetErrorString(errB));
	cudaMemcpy(d_B.elements, B.elements, size, cudaMemcpyHostToDevice);
	printf("Copy B to device: %s\n", cudaGetErrorString(errB));

// invoke kernel
	dim3 dimBlock(BLOCK_SIZE, BLOCK_SIZE);
	dim3 dimGrid( (A.width + dimBlock.x - 1)/dimBlock.x, (A.height + dimBlock.y - 1)/dimBlock.y );
	matPlusScalerKernel<<<dimGrid, dimBlock>>>(d_A, d_B, C);
	cudaError_t err = cudaThreadSynchronize();
	printf("Run kernel: %s\n", cudaGetErrorString(err));

// read A from device memory
	errA = cudaMemcpy(A.elements, d_A.elements, size, cudaMemcpyDeviceToHost);
	printf("Copy A off of device: %s\n",cudaGetErrorString(errA));
// read B from device memory
	errB = cudaMemcpy(B.elements, d_B.elements, size, cudaMemcpyDeviceToHost);
	printf("Copy B off of device: %s\n", cudaGetErrorString(errB));

// free device memory
	cudaFree(d_A.elements);
	cudaFree(d_B.elements);
}

void printMatrix(Matrix A) {
	printf("\n");
	for (int i=0; i<A.height; i++) {
		for (int j=0; j<A.width; j++) {
			printf("%.4f ", A.elements[i*A.width+j]); 
		}
		printf("\n");
	}
	printf("\n");
}

//usage : matPlusScaler height width scaler
int main(int argc, char* argv[]) {

	srand(time(0));	

	Matrix A;
	Matrix B;
	double C;
	int a1, a2;
	// Read some values from the commandline
	a1 = atoi(argv[1]); /* Height of A */
	a2 = atoi(argv[2]); /* Width of A */
	C = atoi(argv[3]); //scaler for addition
	A.height = a1;
	B.height = a1;
	A.width = a2;
	B.width = a2;
	A.elements = (double*)malloc(A.width * A.height * sizeof(double));
	B.elements = (double*)malloc(B.width * B.height * sizeof(double));
	// give A random values
	for(int i = 0; i < A.height; i++)
		for(int j = 0; j < A.width; j++)
			A.elements[i*A.width + j] = ((double)rand()/(double)(RAND_MAX)) * 10;
	// give B random values
	for(int i = 0; i < B.height; i++)
		for(int j = 0; j < B.width; j++)
			B.elements[i*B.width + j] = ((double)rand()/(double)(RAND_MAX)) * 10;
	// call matPlusScaler
	matPlusScaler(A, B, C);
	printMatrix(A);
	printf("C is %f\n", C);
	printMatrix(B);
}
