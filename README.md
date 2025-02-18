# FlexiHist

**FlexiHis** is a software-driven configurable FPGA histogram module that allows assembling various types of buckets. Using a software histogram composer, it automates the design space exploration and is particularly useful in determining how many buckets of what type should result in the most suitable histogram configuration for a specific data distribution.

## Structure of the repository
This repository is structured as follows:
- "FlexiHist/hw_HistogramDesign" contains the hardware design of the histogram. It consists of multiple bucket types, all sharing a common I/O interface, allowing them to be connected in a pipeline to form the final histogram design. The implementations of different bucket types can be found in "hw_HistogramDesign/hw_HistogramDesign.srcs/sources_1/new/".
- "FlexiHist/sw_HistogramComposer" defines the Python-based histogram composer tool. "sw_HistogramComposer/histogramcomposer.py" consists of the software prototypes of the hardware design of buckets along with functions that define the software histogram composer. This module enables reading data from a ```.csv``` file and exploring the design space to determine the optimal histogram configuration taking into account the data distribution. Some sample datasets are available in "sw_HistogramComposer/Data", and the corresponding results can be consulted in "sw_HistogramComposer/Outputs".

### Hardware buckets I/O description

### Software histogram composer important functions
