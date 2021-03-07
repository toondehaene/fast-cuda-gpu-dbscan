#include <bits/stdc++.h>
#include <stdio.h>
#include <stdlib.h>
#include <thrust/binary_search.h>
#include <thrust/device_vector.h>
#include <thrust/execution_policy.h>
#include <thrust/functional.h>
#include <thrust/sort.h>
#include <time.h>

#include <algorithm>
#include <ctime>
#include <fstream>
#include <map>
#include <set>
#include <vector>
using namespace std;

#define THREAD_BLOCKS 12
#define THREAD_COUNT 12

#define gpuErrchk(ans) \
  { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line,
                      bool abort = true) {
  if (code != cudaSuccess) {
    fprintf(stderr, "GPUassert: %s %s %d\n", cudaGetErrorString(code), file,
            line);
    if (abort) exit(code);
  }
}

__global__ void COLLISION_DETECTION(int *collisionMatrix);

int main() {
  int collisionMatrix[THREAD_BLOCKS][THREAD_BLOCKS] = {
      {1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0},
      {0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0},
      {0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0},
      {0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0},
      {1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0},
      {0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0},
      {0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0},
      {0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0}};

  int colMap[THREAD_BLOCKS];
  std::set<int> blockSet;
  for (int i = 0; i < THREAD_BLOCKS; i++) {
    colMap[i] = i;
    blockSet.insert(i);
  }
  std::set<int>::iterator it;
  do {
    it = blockSet.begin();
    int curBlock = *it;
    std::set<int> expansionQueue;
    std::set<int> finalQueue;
    finalQueue.insert(curBlock);
    expansionQueue.insert(curBlock);
    do {
      it = expansionQueue.begin();
      int expandBlock = *it;
      expansionQueue.erase(expandBlock);
      blockSet.erase(expandBlock);
      for (int x = 0; x < THREAD_BLOCKS; x++) {
        if (x == expandBlock) continue;
        if ((collisionMatrix[expandBlock][x] == 1 ||
             collisionMatrix[x][expandBlock]) &&
            blockSet.find(x) != blockSet.end()) {
          expansionQueue.insert(x);
          finalQueue.insert(x);
        }
      }
    } while (expansionQueue.empty() == 0);

    for (it = finalQueue.begin(); it != finalQueue.end(); ++it) {
      colMap[*it] = curBlock;
    }
  } while (blockSet.empty() == 0);

  for (int i = 0; i < THREAD_BLOCKS; i++) {
    cout << i << ": " << colMap[i] << endl;
  }

  cout << "############################" << endl;

  int *d_collisionMatrix;
  gpuErrchk(cudaMalloc((void **)&d_collisionMatrix,
                       sizeof(int) * THREAD_BLOCKS * THREAD_BLOCKS));

  gpuErrchk(cudaMemcpy(d_collisionMatrix, collisionMatrix,
                       sizeof(int) * THREAD_BLOCKS * THREAD_BLOCKS,
                       cudaMemcpyHostToDevice));
  gpuErrchk(cudaDeviceSynchronize());
  COLLISION_DETECTION<<<dim3(THREAD_BLOCKS, 1), dim3(THREAD_COUNT, 1)>>>(
      d_collisionMatrix);
  gpuErrchk(cudaDeviceSynchronize());
  return 0;
}

__global__ void COLLISION_DETECTION(int *collisionMatrix) {
  if (blockIdx.x == 0 && threadIdx.x == 0) {
    int colMap[THREAD_BLOCKS];
    int blockSet[THREAD_BLOCKS];
    for (int i = 0; i < THREAD_BLOCKS; i++) {
      colMap[i] = i;
      blockSet[i] = i;
    }
    int blocksetCount = THREAD_BLOCKS;
    while (blocksetCount > 0) {
      int curBlock = blockSet[0];
      int expansionQueue[THREAD_BLOCKS * THREAD_BLOCKS];
      int finalQueue[THREAD_BLOCKS * THREAD_BLOCKS];
      int expansionQueueCount = 0;
      int finalQueueCount = 0;
      expansionQueue[expansionQueueCount++] = curBlock;
      finalQueue[finalQueueCount++] = curBlock;
      while (expansionQueueCount > 0) {
        int expandBlock = expansionQueue[--expansionQueueCount];
        thrust::remove(thrust::device, expansionQueue,
                       expansionQueue + THREAD_BLOCKS, expandBlock);
        thrust::remove(thrust::device, blockSet, blockSet + THREAD_BLOCKS,
                       expandBlock);
        blocksetCount--;
        for (int x = 0; x < THREAD_BLOCKS; x++) {
          if (x == expandBlock) continue;
          if ((collisionMatrix[expandBlock * THREAD_BLOCKS + x] == 1 ||
               collisionMatrix[x * THREAD_BLOCKS + expandBlock]) &&
              thrust::find(thrust::device, blockSet, blockSet + THREAD_BLOCKS,
                           x) != blockSet + THREAD_BLOCKS) {
            expansionQueue[expansionQueueCount++] = x;
            finalQueue[finalQueueCount++] = x;
          }
        }
      };

      for (int c = 0; c < finalQueueCount; c++) {
        colMap[finalQueue[c]] = curBlock;
      }
    };

    for (int i = 0; i < THREAD_BLOCKS; i++) {
      printf("%d -> %d\n", i, colMap[i]);
    }
  }
}