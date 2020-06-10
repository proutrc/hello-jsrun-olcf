CUCOMP  = nvcc
CUFLAGS = -arch=sm_70 -Xcompiler -fopenmp

INCLUDES  = -I$(OMPI_DIR)/include
LIBRARIES = -L$(OMPI_DIR)/lib -L$(CUDA_DIR)/targets/ppc64le-linux/lib/stubs -lmpi_ibm -lnvidia-ml

hello_jsrun: hello_jsrun.o
	$(CUCOMP) $(CUFLAGS) $(LIBRARIES) hello_jsrun.o -o hello_jsrun

hello_jsrun.o: hello_jsrun.cu
	$(CUCOMP) $(CUFLAGS) $(INCLUDES) -c hello_jsrun.cu

.PHONY: clean

clean:
	rm -f hello_jsrun *.o
