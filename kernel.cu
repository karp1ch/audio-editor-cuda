#include <iostream>
#include <fstream>
#include <vector>
#include <cuda_runtime.h>

struct WavHeader {
    char riff[4];
    uint32_t fileSize;
    char wave[4];
    char fmt[4];
    uint32_t fmtSize;
    uint16_t audioFormat;
    uint16_t numChannels;
    uint32_t sampleRate;
    uint32_t byteRate;
    uint16_t blockAlign;
    uint16_t bitsPerSample;
    char data[4];
    uint32_t dataSize;
};


__global__ void removeNoise(char* data, int dataSize, float threshold, int startSample, int endSample, float noiseReductionFactor = 0.4f) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= startSample && idx < endSample) {
        data[idx] = 0;
    }
    else {
        if (abs(data[idx]) < threshold) {
            float amplitude = static_cast<float>(data[idx]) / 32768.0f;
            amplitude *= noiseReductionFactor;
            data[idx] = static_cast<char>(amplitude * 32768.0f);
        }
    }
}

__global__ void calculateNoiseThresholdKernel(const char* data, int dataSize, int sampleRate, float* result, int startSample, int endSample, uint16_t numChannels) {
    // check 
    startSample = min(startSample, dataSize);
    endSample = min(endSample, dataSize);

    __shared__ float sharedData[1024];
    int tid = threadIdx.x;
    int i = blockIdx.x * blockDim.x + threadIdx.x;


    if (i < dataSize) {
        sharedData[tid] = abs(static_cast<float>(data[i]));
    }
    __syncthreads();

    for (int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) {
            sharedData[tid] += sharedData[tid + s];
        }
        __syncthreads();
    }


    if (tid == 0)
        atomicAdd(result, sharedData[0]);
}

__global__ void increaseVolume(char* data, int dataSize, float gainDb) {
    const float gainLinear = powf(10.0, gainDb / 20.0);
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < dataSize) {
        float sample = static_cast<float>(data[idx]) / 32768.0f;
        sample *= gainLinear;

        if (sample > 1.0f) sample = 1.0f;
        if (sample < -1.0f) sample = -1.0f;

        data[idx] = static_cast<char>(sample * 32768.0f);
    }
}

__global__ void normalizeAudio(char* data, int dataSize, float targetLevel, float threshold) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < dataSize) {
        float sample = static_cast<float>(data[idx]) / 32768.0f;
        sample *= targetLevel;
        data[idx] = static_cast<char>(sample * 32768.0f);
    }
}

__global__ void addReverb(char* data, int dataSize, int delaySamples, float decay) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int delayedIdx = idx - delaySamples;
    if (idx < dataSize && delayedIdx >= 0) {
        float delayedSample = static_cast<float>(data[delayedIdx]) / 32768.0f;
        float currentSample = static_cast<float>(data[idx]) / 32768.0f;
        float reverbSample = currentSample + delayedSample * decay;
        data[idx] = static_cast<char>(reverbSample * 32768.0f);
    }
}

__global__ void fadeIn(char* data, int dataSize, int fadeLength) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < fadeLength) {
        float fadeFactor = static_cast<float>(idx) / fadeLength;
        float sample = static_cast<float>(data[idx]) / 32768.0f;
        sample *= fadeFactor;
        data[idx] = static_cast<char>(sample * 32768.0f);
    }
}

__global__ void fadeOut(char* data, int dataSize, int fadeLength) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int fadeStartIdx = dataSize - fadeLength;
    if (idx >= fadeStartIdx && idx < dataSize) {
        float fadeFactor = static_cast<float>(dataSize - idx) / fadeLength;
        float sample = static_cast<float>(data[idx]) / 32768.0f;
        sample *= fadeFactor;
        data[idx] = static_cast<char>(sample * 32768.0f);
    }
}

__global__ void changeSpeed(const char* in_data, char* out_data, int in_dataSize, float speedFactor, uint16_t numChannels) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int outIdx = idx * numChannels;

    if (outIdx < in_dataSize) {
        float srcIdx = idx * speedFactor;
        int srcIdxInt = static_cast<int>(srcIdx) * numChannels;
        int srcIdxNext = min(srcIdxInt + numChannels, in_dataSize - numChannels);
        float frac = srcIdx - static_cast<int>(srcIdx);

        for (int channel = 0; channel < numChannels; ++channel) {
            if (srcIdxInt + channel < in_dataSize && srcIdxNext + channel < in_dataSize) {
                short sample1 = static_cast<short>((in_data[srcIdxInt + channel] << 8) | (in_data[srcIdxInt + channel + 1] & 0xFF));
                short sample2 = static_cast<short>((in_data[srcIdxNext + channel] << 8) | (in_data[srcIdxNext + channel + 1] & 0xFF));

                float interpSample = (1.0f - frac) * sample1 + frac * sample2;
                interpSample = max(min(interpSample, 32767.0f), -32768.0f);

                out_data[outIdx + channel] = static_cast<char>((static_cast<short>(interpSample) >> 8) & 0xFF);
                out_data[outIdx + channel + 1] = static_cast<char>(static_cast<short>(interpSample) & 0xFF);
            }
        }
    }
}





int main() {
    const char* inputFileName = "input.wav";
    const char* outputFileName = "output.wav";

    // open
    std::ifstream inputFile(inputFileName, std::ios::binary);
    if (!inputFile.is_open()) {
        std::cerr << "Error opening input file." << std::endl;
        return 1;
    }

    // header
    WavHeader header;
    inputFile.read(reinterpret_cast<char*>(&header), sizeof(WavHeader));
    std::cout << "Channels: " << header.numChannels << std::endl;
    std::cout << "Sample Rate: " << header.sampleRate << std::endl;
    std::cout << "Bits Per Sample: " << header.bitsPerSample << std::endl;


    // is supported
    if (header.audioFormat != 1 || header.bitsPerSample != 16) {
        std::cerr << "Unsupported audio format or bits per sample." << std::endl;
        return 1;
    }

    // length
    float audioDuration = static_cast<float>(header.dataSize) / (header.sampleRate * header.numChannels * (header.bitsPerSample / 8));

    std::cout << "Audio Duration: " << audioDuration << " seconds" << std::endl;

    // enter parametrs
    const float targetLevel = 0.85f;
    float startSeconds, endSeconds, gainDb, noiseThreshold, decay, fade, speedFactor;;
    std::cout << "Enter start time in seconds (Noise sample): ";
    std::cin >> startSeconds;
    std::cout << "Enter end time in seconds (Noise sample): ";
    std::cin >> endSeconds;
    std::cout << "Enter gain in dB: ";
    std::cin >> gainDb;
    std::cout << "Enter reverb coeff: ";
    std::cin >> decay;
    std::cout << "Enter fade length: ";
    std::cin >> fade;
    std::cout << "Change speed" << std::endl;
    std::cin >> speedFactor;
    int new_dataSize = static_cast<int>(header.dataSize / speedFactor);
    
    
    // reading data
    std::vector<char> dataBuffer(header.dataSize);
    inputFile.read(dataBuffer.data(), header.dataSize);

    // CUDA malloc
    float* d_result;
    cudaMalloc((void**)&d_result, sizeof(float));

    char* d_data;
    cudaMalloc((void**)&d_data, header.dataSize);
    cudaMemcpy(d_data, dataBuffer.data(), header.dataSize, cudaMemcpyHostToDevice);

    char* d_newData;
    cudaMalloc((void**)&d_newData, new_dataSize);

    // CUDA grid
    int blockSize;
    int minGridSize, gridSize;
    cudaOccupancyMaxPotentialBlockSize(&minGridSize, &blockSize, removeNoise, 0, header.dataSize);
    gridSize = (header.dataSize + blockSize - 1) / blockSize;

    // convert sample2time
    int startSample = static_cast<int>(startSeconds * header.sampleRate * header.numChannels * header.numChannels);
    int endSample = static_cast<int>(endSeconds * header.sampleRate * header.numChannels * header.numChannels);
    int fadeLength = static_cast<int>(fade * header.sampleRate * header.numChannels * header.numChannels);
    int delaySamples = static_cast<int>(0.5f * header.sampleRate);

    // kernels
    calculateNoiseThresholdKernel << <gridSize, blockSize >> > (d_data, header.dataSize, header.sampleRate, d_result, startSample, endSample, header.numChannels);
    cudaMemcpy(&noiseThreshold, d_result, sizeof(float), cudaMemcpyDeviceToHost);

    // Calculate mean over the samples
    int numSamples = endSample - startSample;
    noiseThreshold /= (numSamples * header.numChannels * header.numChannels * header.bitsPerSample);
    std::cout << "Automatic Noise Threshold: " << noiseThreshold << std::endl;

    removeNoise << <gridSize, blockSize >> > (d_data, header.dataSize, noiseThreshold, startSample, endSample);
    cudaMemcpy(dataBuffer.data(), d_data, header.dataSize, cudaMemcpyDeviceToHost);


    increaseVolume << <gridSize, blockSize >> > (d_data, header.dataSize, gainDb);
    cudaMemcpy(dataBuffer.data(), d_data, header.dataSize, cudaMemcpyDeviceToHost);


    normalizeAudio << <gridSize, blockSize >> > (d_data, header.dataSize, targetLevel, noiseThreshold);
    cudaMemcpy(dataBuffer.data(), d_data, header.dataSize, cudaMemcpyDeviceToHost);


    addReverb << <gridSize, blockSize >> > (d_data, header.dataSize, delaySamples, decay);
    cudaMemcpy(dataBuffer.data(), d_data, header.dataSize, cudaMemcpyDeviceToHost);

    fadeIn << <gridSize, blockSize >> > (d_data, header.dataSize, fadeLength);
    cudaMemcpy(dataBuffer.data(), d_data, header.dataSize, cudaMemcpyDeviceToHost);
    fadeOut << <gridSize, blockSize >> > (d_data, header.dataSize, fadeLength);
    cudaMemcpy(dataBuffer.data(), d_data, header.dataSize, cudaMemcpyDeviceToHost);

    gridSize = (new_dataSize + blockSize - 1) / blockSize;
    changeSpeed << <gridSize, blockSize >> > (d_data, d_newData, header.dataSize, speedFactor, header.numChannels);
    header.dataSize = new_dataSize;
    std::vector<char> newDataBuffer(new_dataSize);
    cudaMemcpy(newDataBuffer.data(), d_newData, new_dataSize, cudaMemcpyDeviceToHost);


    // CUDA free
    cudaFree(d_result);
    cudaFree(d_data);
    cudaFree(d_newData);


    // save output
    std::ofstream outputFile(outputFileName, std::ios::binary);
    if (!outputFile.is_open()) {
        std::cerr << "Error opening output file." << std::endl;
        return 1;
    }

    outputFile.write(reinterpret_cast<const char*>(&header), sizeof(WavHeader));
    outputFile.write(newDataBuffer.data(), new_dataSize);

    std::cout << "File processing completed successfully." << std::endl;

    return 0;
}
