# FlexiHist

**FlexiHis** is a software-driven configurable FPGA histogram module that allows assembling various types of buckets. Using a software histogram composer, it automates the design space exploration and is particularly useful in determining how many buckets of what type should result in the most suitable histogram configuration for a specific data distribution.

## Structure of the repository
This repository is structured as follows:
- ```FlexiHist/hw_HistogramDesign``` contains the hardware design of the histogram. It consists of multiple bucket types, all sharing a common I/O interface, allowing them to be connected in a pipeline to form the final histogram design. The implementations of different bucket types can be found in ```FlexiHist/hw_HistogramDesign/hw_HistogramDesign.srcs/sources_1/new/```.
- ```FlexiHist/sw_HistogramComposer``` defines the Python-based histogram composer tool. ```FlexiHist/sw_HistogramComposer/histogramcomposer.py``` consists of the software prototypes of the hardware design of buckets along with functions that define the software histogram composer. This module allows reading data from a ```.csv``` file and exploring the design space to determine the optimal histogram configuration taking into account the data distribution. Some sample datasets are available in ```FlexiHist/sw_HistogramComposer/Data```, and the corresponding results can be consulted in ```FlexiHist/sw_HistogramComposer/Outputs```.

### Hardware buckets I/O description
Buckets are designed in a streaming fashion, sharing a common AXI4-Stream-compliant I/O interface, ensuring interoperability. The generic bucket interface, defined in ```hw_HistogramDesign/hw_HistogramDesign.srcs/sources_1/new/GenericBucket.vhd```, enables the conditional synthesis of various bucket types based on the ```BUCKET_TYPE``` generic parameter. This interface incorporates a set of generic parameters applicable to all bucket types, but each type of bucket requires just a subset of the generic parameters defined in the generic interface.
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

| Port Name          | Description |
|--------------------|-------------|
| **aclk**          | Clock signal driving the design |
| **nrst**          | Active-low reset signal |
| **s_axis_in**     | Input AXI4-Stream interface, including:  |
|                  | - **s_axis_in_tvalid**: Indicates when valid data is present. |
|                  | - **s_axis_in_tready**: Indicates when the module is ready to receive data. |
|                  | - **s_axis_in_tdata**: Data input (68-bit wide). |
|                  | - **s_axis_in_tdest**: Destination identifier for routing (32-bit wide). |
| **m_axis_out**    | Output AXI4-Stream interface, including:  |
|                  | - **m_axis_out_tvalid**: Indicates when valid output data is available. |
|                  | - **m_axis_out_tready**: Indicates when the receiver is ready to accept data. |
|                  | - **m_axis_out_tdata**: Data output (68-bit wide). |
|                  | - **m_axis_out_tdest**: Destination identifier for routing (32-bit wide). |

To define a specific histogram, multiple buckets are connected as a pipeline. The histogram processes a single data stream containing both samples and metadata. Initially, the metadata specifies the operation code, and as the data moves through the histogram's buckets, it accumulates statistical information.

### Software histogram composer important functions
