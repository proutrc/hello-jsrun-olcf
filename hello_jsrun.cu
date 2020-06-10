/**********************************************************

"Hello World"-type program to test different jsrun layouts.

Written by Tom Papatheodore

**********************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <mpi.h>
#include <sched.h>
#include <nvml.h>
#include <omp.h>

int main(int argc, char *argv[]){

	MPI_Init(&argc, &argv);

	int size;
	MPI_Comm_size(MPI_COMM_WORLD, &size);

	int rank;
	MPI_Comm_rank(MPI_COMM_WORLD, &rank);

	char name[MPI_MAX_PROCESSOR_NAME];
	int resultlength;
	MPI_Get_processor_name(name, &resultlength);

	cudaError_t cuErr;

	// Find how many GPUs CUDA runtime says are available
	int num_devices = 0;
	cuErr = cudaGetDeviceCount(&num_devices);

	// Set output based on command line argument
	// => verbose shows BusID and UUID for GPUs
	char output_flag[64];
	strcpy(output_flag, "not_verbose");
	if(argc > 1){ 
		if(strlen(argv[1]) >= sizeof(output_flag)){
			printf("Argument too long: %s\n", argv[1]);
			exit(0);
		}
		else{
			strcpy(output_flag, argv[1]);
		}
	}

	int hwthread;
	int num_threads = 0;
	int thread_id = 0;

	#pragma omp parallel default(shared)
	{
		num_threads = omp_get_num_threads();
	}

	if(rank == 0){
		printf("\n---------- MPI Ranks: %d, OpenMP Threads: %d, GPUs per Resource Set: %d ----------\n", size, num_threads, num_devices);
	}

	if(num_devices == 0){
		#pragma omp parallel default(shared) private(hwthread, thread_id)
		{
			thread_id = omp_get_thread_num();
			hwthread = sched_getcpu();

			printf("MPI Rank %03d of %03d on HWThread %03d of Node %s, OMP_threadID %d of %d\n", rank, size, hwthread, name, thread_id, num_threads);
		}
	}
	else{

		// NVML is needed to query the UUID of GPUs, which
		// allows us to check which GPU is actually being used
		// by each MPI rank
		nvmlReturn_t result;
		result = nvmlInit();
		if(NVML_SUCCESS != result){
			printf("Failed to initialize NVML: %s\n", nvmlErrorString(result));
			exit(0);
		}
		char uuid[NVML_DEVICE_UUID_BUFFER_SIZE];
		char busid[64];
		int gpu_id;

		char uuid_list[1024] = "";
		char busid_list[1024] = "";
		char rt_gpu_id_list[1024] = "";
		char gpu_id_list[1024] = "";

		char c_i[12] = "";
		char c_gpu_id[12] = "";

		// Loop over the GPUs available to each MPI rank
		for(int i=0; i<num_devices; i++){

			cuErr = cudaSetDevice(i);
			if(cudaSuccess != cuErr){
				printf("CUDA Error - cudaSetDevice: %s/n", cudaGetErrorString(cuErr));
				exit(0);
			}

			// Get the PCIBusId for each GPU and use it to query for UUID
			cuErr = cudaDeviceGetPCIBusId(busid, 64, i);
			if(cudaSuccess != cuErr){
				printf("CUDA Error - cudaDeviceGetPCIBusId: %s/n", cudaGetErrorString(cuErr));
				exit(0);
			}

			// Get UUID for the device based on busid
			nvmlDevice_t device;

			result = nvmlDeviceGetHandleByPciBusId(busid, &device);
			if(NVML_SUCCESS != result){
				printf("nvmlDeviceGetHandleByPciBusId Failed: %s\n", nvmlErrorString(result));
				exit(0);
			}	

			result = nvmlDeviceGetUUID(device, uuid, NVML_DEVICE_UUID_BUFFER_SIZE);
			if(NVML_SUCCESS != result){
				printf("nvmlDeviceGetUUID Failed: %s\n", nvmlErrorString(result));
				exit(0);
			}

			// Map DomainID and BusID to node-local GPU ID
			if(strcmp(busid, "0004:04:00.0") == 0){
				gpu_id = 0;
			}else if(strcmp(busid, "0004:05:00.0") == 0){
				gpu_id = 1;
			}else if(strcmp(busid, "0004:06:00.0") == 0){
				gpu_id = 2;
			}else if(strcmp(busid, "0035:03:00.0") == 0){
				gpu_id = 3;
			}else if(strcmp(busid, "0035:04:00.0") == 0){
				gpu_id = 4;
			}else if(strcmp(busid, "0035:05:00.0") == 0){
				gpu_id = 5;
			}else if(strcmp(busid, "0002:01:00.0") == 0){
				gpu_id = 0;
			}else if(strcmp(busid, "0003:01:00.0") == 0){
				gpu_id = 1;
			}else if(strcmp(busid, "0006:01:00.0") == 0){
				gpu_id = 2;
			}else if(strcmp(busid, "0007:01:00.0") == 0){
				gpu_id = 3;
			}else{
				printf("The BusID (%s) did not map correctly to a GPU. Exiting...\n", busid);
				exit(0);
			}

			// Concatenate per-MPIrank GPU info into strings for printf
			sprintf(c_i, "%d", i);
			sprintf(c_gpu_id, "%d", gpu_id);

			strcat(rt_gpu_id_list, strcat(c_i, " "));
			strcat(gpu_id_list, strcat(c_gpu_id, " "));
			strcat(busid_list, strcat(busid, " "));
			strncat(uuid_list, uuid, 10*sizeof(char));
			strcat(uuid_list, " ");

		}

		#pragma omp parallel default(shared) private(hwthread, thread_id)
		{
			thread_id = omp_get_thread_num();
			hwthread = sched_getcpu();

			if(strcmp(output_flag, "verbose") == 0){
				printf("MPI Rank %03d, OMP_thread %02d on HWThread %03d of Node %s - RT_GPU_id %s: GPU_id %s, BusID %s, UUID %s\n", rank, thread_id, hwthread, name, rt_gpu_id_list, gpu_id_list, busid_list, uuid_list);
			}
			else{
				printf("MPI Rank %03d, OMP_thread %02d on HWThread %03d of Node %s - RT_GPU_id %s: GPU_id %s\n", rank, thread_id, hwthread, name, rt_gpu_id_list, gpu_id_list);	
			}
		}

		result = nvmlShutdown();
		if(NVML_SUCCESS != result){
			printf("NVML Failed to Shutdown: %s\n", nvmlErrorString(result));
			exit(0);
		}

	}

	MPI_Finalize();

	return 0;
}
