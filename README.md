# FlexiHist

**FlexiHis** is a software-driven configurable FPGA histogram module that allows assembling various types of buckets. Using a software histogram composer, it automates the design space exploration and is particularly useful in determining how many buckets of what type should result in the most suitable histogram configuration for a specific data distribution.

## Structure of the repository
This repository is structured as follows:
- ```FlexiHist/hw_HistogramDesign``` contains the hardware design of the histogram. It consists of multiple bucket types, all sharing a common I/O interface, allowing them to be connected in a pipeline to form the final histogram design. The implementations of different bucket types can be found in ```FlexiHist/hw_HistogramDesign/hw_HistogramDesign.srcs/sources_1/new/```.
- ```FlexiHist/sw_HistogramComposer``` defines the Python-based histogram composer tool. ```FlexiHist/sw_HistogramComposer/histogramcomposer.py``` consists of the software prototypes of the hardware design of buckets along with functions that define the software histogram composer. This module allows reading data from a ```.csv``` file and exploring the design space to determine the optimal histogram configuration taking into account the data distribution. Some sample datasets are available in ```FlexiHist/sw_HistogramComposer/Data```, and the corresponding results can be consulted in ```FlexiHist/sw_HistogramComposer/Outputs```.

### Hardware buckets I/O description
Buckets are designed in a streaming fashion, sharing a common AXI4-Stream-compliant I/O interface, ensuring interoperability. The generic bucket interface, defined in ```FlexiHist/hw_HistogramDesign/hw_HistogramDesign.srcs/sources_1/new/GenericBucket.vhd```, enables the conditional synthesis of various bucket types based on the ```BUCKET_TYPE``` generic parameter. This interface incorporates a set of generic parameters applicable to all bucket types, but each type of bucket requires just a subset of the generic parameters defined in the generic interface.

The generic parameters are:

| Parameter              | Description                                      |
|------------------------|--------------------------------------------------|
| `BUCKET_ID`           | Identifier for the bucket                        |
| `BUCKET_TYPE`         | Type of the bucket                  |
| `MAX_BUCKET_SIZE`     | Maximum size of the bucket expressed as the difference between its higher bound and its lower bound (default: 512)        |
| `NUM_SUB_BUCKETS_BITS`| Number of bits in the binary representation of the number of sub-buckets (default: 7) |
| `NUM_HASHES`         | Number of hash functions (range: 3 to 5, default: 4) |
| `FILTER_SIZE_BITS`   | Size of the filter in bits (range: 1 to 32, default: 10) |

The I/O ports of this generic interface are:

| Port Name      | Description |
|---------------|-------------|
| `aclk`      | Clock signal driving the design |
| `nrst`      | Active-low reset signal |
| `s_axis_in` | **Input AXI4-Stream interface** <br> - `s_axis_in_tvalid`: Indicates when valid data is present <br> - `s_axis_in_tready`: Indicates when the module is ready to receive data <br> - `s_axis_in_tdata`: Data input (68-bit wide) <br> - `s_axis_in_tdest`: Destination identifier (32-bit wide) |
| `m_axis_out` | **Output AXI4-Stream interface** <br> - `m_axis_out_tvalid`: Indicates when valid output data is available <br> - `m_axis_out_tready`: Indicates when the receiver is ready to accept data <br> - `m_axis_out_tdata`: Data output (68-bit wide) <br> - `m_axis_out_tdest`: Destination identifier for routing (32-bit wide) |


To define a specific histogram, multiple buckets are connected as a pipeline. The histogram processes a single data stream containing both samples and metadata. Initially, the metadata specifies the operation code, and as the data moves through the histogram's buckets, it accumulates statistical information.

### Software histogram composer important functions

Besides defining the software prorotype of all hardware modules, the histogram composer (```FlexiHist/sw_HistogramComposer/histogramcomposer.py```) is responsible of automating the design space exploration in order to identify the best histogram configuration for a given data excerpt.

The main functions implemented by the histogram composer are:

| Function | Description |
|----------|-------------|
| `histogram_configuration(data, ground_truth_histo, num_buckets, strategy)` | Splits the ground truth histogram (per value count) according to the specified strategy: equi-width, equi-depth, or equi-distinct-count |
| `construct_candidates(data, ground_truth_histo, resource_budget, num_buckets, split_strategy, bit)` | Constructs a candidate list of buckets for each data segment based on the histogram configuration returned by `histogram_configuration` |
| `greedy_min_error_histogram(candidate_buckets, resource_budget, eps=10, opt_resources=False)` | Greedy approach that selects the candidate bucket for each segment that minimizes error while ensuring the total resource budget is not exceeded |
| `greedy_avg_res_histogram(candidate_buckets, resource_budget, eps=10000, opt_resources=False)` | Greedy approach that selects the candidate bucket for each segment while balancing error minimization and not exceeding an average per-bucket resource consumption |
| `simulated_annealing_histogram(candidate_buckets, resource_budget, first_sol='first', alpha=0.5, initial_temp=1000, cooling_rate=0.995, max_iterations=100000)` | Uses simulated annealing to find the optimal histogram configuration while also considering resource constraints |
| `run(data_path, resource_budget, num_buckets, algorithm, split_strategy)` | Explores the design space for a fixed number of buckets in the histogram using a specified algorithm |
| `run_all(data_path, outputs_path, resource_budget, max_num_buckets)` | Iteratively explores the design space for an increasing number of buckets, generating configurations for varying number of buckets in the histogram |
