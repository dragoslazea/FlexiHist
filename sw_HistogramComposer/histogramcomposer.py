import numpy as np
import random
import math
import matplotlib.pyplot as plt
import csv

class Bucket:
  def __init__(self):
    self.low = 0
    self.high = 0
    self.count = 0
    self.is_configured = False

  def config(self, low, high):
    if self.is_configured == False:
      self.low = low
      self.high = high
      self.count = 0
      self.is_configured = True

  def update(self, val):
    if self.is_configured == True and val >= self.low and val < self.high:
      self.count += 1

  def read(self, val):
    if self.is_configured == True and val >= self.low and val < self.high:
      return self.count
    else:
      return 0

  def display_info(self):
    print(f"[low: {self.low}, high: {self.high}, count: {self.count}]")


class CoarseGrainedSimpleBucket(Bucket):
  resources = (193, 301, 0, 0) # (LUTs, FFs, BRAM, DSPs)
  latency = 1 # clock cycles

  def __init__(self):
    super().__init__()
    self.LUT = 193
    self.FF = 301
    self.BRAM = 0
    self.DSP = 0

  def get_resource_consumption(self):
    return (self.LUT, self.FF, self.BRAM, self.DSP)

  @classmethod
  def create_default_bucket(cls, size):
    return CoarseGrainedSimpleBucket()

  @classmethod
  def get_resources_of_bucket(cls, size):
    return cls.resources

  def avg_resource_usage(self, available_budget=None):
    if available_budget == None:
      return (self.LUT + self.FF + self.BRAM + self.DSP) / 4
    else:
      normalized_usage = tuple(a / b for a, b in zip(self.get_resource_consumption(), available_budget))
      nLUT, nFF, nBRAM, nDSP = normalized_usage
      return (nLUT + nFF + nBRAM + nDSP) / 4

  def weighted_resource_usage(self, available_budget):
    LUT, FF, BRAM, DSP = self.get_resource_consumption()
    aLUT, aFF, aBRAM, aDSP = available_budget
    total_res = aLUT + aFF + aBRAM + aDSP
    wLUT = aLUT / total_res
    wFF = aFF / total_res
    wBRAM = aBRAM / total_res
    wDSP = aDSP / total_res
    return (wLUT * LUT + wFF * FF + wBRAM * BRAM + wDSP * DSP) / total_res

class CoarseGrainedDistinctBucket(Bucket):
  resources_S = (1489, 403, 0, 0) # (LUTs, FFs, BRAM, DSPs) for 64-bit bit-array
  resources_M = (1815, 595, 0, 0) # (LUTs, FFs, BRAM, DSPs) for 256-bit bit-array
  resources_L = (2105, 851, 0, 0) # (LUTs, FFs, BRAM, DSPs) for 512-bit bit-array

  latency = 1 # clock cycles

  def __init__(self, max_distincts):
    super().__init__()
    self.distinct_count = 0
    self.max_distincts = max_distincts
    self.distincts = [0] * self.max_distincts

    if max_distincts <= 64:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_S
    elif max_distincts <= 256:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_M
    else:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_L

  def config(self, low, high):
    if self.is_configured == False:
      self.low = low
      self.high = high
      self.count = 0
      self.distinct_count = 0
      self.distincts = [0] * self.max_distincts
      self.is_configured = True

  def update(self, val):
    if self.is_configured == True and val >= self.low and val < self.high:
      self.count += 1
      if self.distincts[val % self.max_distincts] == 0:
        self.distinct_count += 1
        self.distincts[val % self.max_distincts] = 1

  def get_resource_consumption(self):
    return (self.LUT, self.FF, self.BRAM, self.DSP)

  @classmethod
  def get_resources_of_bucket(cls, size):
    if size == 'S':
      return cls.resources_S
    elif size == 'M':
      return cls.resources_M
    else:
      return cls.resources_L

  @classmethod
  def create_default_bucket(cls, size):
    if size == 'S':
      return CoarseGrainedDistinctBucket(64)
    elif size == 'M':
      return CoarseGrainedDistinctBucket(256)
    else:
      return CoarseGrainedDistinctBucket(512)

  def avg_resource_usage(self, available_budget=None):
    if available_budget == None:
      return (self.LUT + self.FF + self.BRAM + self.DSP) / 4
    else:
      normalized_usage = tuple(a / b for a, b in zip(self.get_resource_consumption(), available_budget))
      nLUT, nFF, nBRAM, nDSP = normalized_usage
      return (nLUT + nFF + nBRAM + nDSP) / 4

  def weighted_resource_usage(self, available_budget):
    LUT, FF, BRAM, DSP = self.get_resource_consumption()
    aLUT, aFF, aBRAM, aDSP = available_budget
    total_res = aLUT + aFF + aBRAM + aDSP
    wLUT = aLUT / total_res
    wFF = aFF / total_res
    wBRAM = aBRAM / total_res
    wDSP = aDSP / total_res
    return (wLUT * LUT + wFF * FF + wBRAM * BRAM + wDSP * DSP) / total_res

  def read(self, val):
    if self.is_configured == True and val >= self.low and val < self.high and self.distinct_count > 0:
      return int(self.count / self.distinct_count)
    else:
      return 0

  def display_info(self):
    print(f"[low: {self.low}, high: {self.high}, count: {self.count}, distinct count: {self.distinct_count}]")

def murmur3(key: int, seed: int) -> int:
    h = seed
    k = key

    k *= 0xcc9e2d51
    k &= 0xFFFFFFFF

    k = (k << 15) | (k >> 17)
    k &= 0xFFFFFFFF

    k *= 0x1b873593
    k &= 0xFFFFFFFF

    h ^= k
    h = (h << 13) | (h >> 19)
    h &= 0xFFFFFFFF

    h = h * 5 + 0xe6546b64
    h &= 0xFFFFFFFF

    h ^= 4
    h ^= h >> 16
    h *= 0x85ebca6b
    h &= 0xFFFFFFFF
    h ^= h >> 13
    h *= 0xc2b2ae35
    h &= 0xFFFFFFFF
    h ^= h >> 16

    return h

class CoarseGrainedBloomBucket(Bucket):

  seeds = [0x92d6a354, 0x8bf65351, 0x960b7a1f, 0x9d670b00, 0xb32d6bd1]

  resources_S = (1729, 349, 0, 30) # (LUTs, FFs, BRAM, DSPs) for 2 ** 4 = 16
  resources_M = (2892, 589, 0, 30) # (LUTs, FFs, BRAM, DSPs) for 2 ** 8 = 256
  resources_L = (6198, 1357, 0, 30) # (LUTs, FFs, BRAM, DSPs) for 2 ** 10 = 1024

  latency = 1 # clock cycles

  def __init__(self, num_hashes, filter_size_bits):
    super().__init__()
    self.distinct_count = 0
    self.is_configured = False
    self.num_hashes = num_hashes
    self.filter_size_bits = filter_size_bits
    self.filter_size = 2 ** filter_size_bits
    self.bloom_filter = [False] * self.filter_size

    if filter_size_bits <= 4:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_S
    elif filter_size_bits <= 8:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_M
    else:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_L

  def config(self, low, high):
    if self.is_configured == False:
      self.low = low
      self.high = high
      self.count = 0
      self.distinct_count = 0
      self.is_configured = True
      self.bloom_filter = [False] * self.filter_size

  def update(self, val):
    if self.is_configured == True and val >= self.low and val < self.high:
      self.count += 1

      query = True

      for i in range(self.num_hashes):
        h = murmur3(val, self.seeds[i]) % self.filter_size

        if self.bloom_filter[h] == False:
          query = False

        self.bloom_filter[h] = True

      if query == False:
        self.distinct_count += 1

  def read(self, val):
    if self.is_configured == True and val >= self.low and val < self.high:
      query = True
      for i in range(self.num_hashes):
        h = murmur3(val, self.seeds[i]) % self.filter_size

        if self.bloom_filter[h] == False:
          query = False

      if query == False:
        return 0
      else:
        return int(self.count / self.distinct_count)

    else:
      return 0

  def get_resource_consumption(self):
    return (self.LUT, self.FF, self.BRAM, self.DSP)

  @classmethod
  def get_resources_of_bucket(cls, size):
    if size == 'S':
      return cls.resources_S
    elif size == 'M':
      return cls.resources_M
    else:
      return cls.resources_L

  @classmethod
  def create_default_bucket(cls, size):
    if size == 'S':
      return CoarseGrainedBloomBucket(3, 4)
    elif size == 'M':
      return CoarseGrainedBloomBucket(3, 8)
    else:
      return CoarseGrainedBloomBucket(3, 10)

  def avg_resource_usage(self, available_budget=None):
    if available_budget == None:
      return (self.LUT + self.FF + self.BRAM + self.DSP) / 4
    else:
      normalized_usage = tuple(a / b for a, b in zip(self.get_resource_consumption(), available_budget))
      nLUT, nFF, nBRAM, nDSP = normalized_usage
      return (nLUT + nFF + nBRAM + nDSP) / 4

  def weighted_resource_usage(self, available_budget):
    LUT, FF, BRAM, DSP = self.get_resource_consumption()
    aLUT, aFF, aBRAM, aDSP = available_budget
    total_res = aLUT + aFF + aBRAM + aDSP
    wLUT = aLUT / total_res
    wFF = aFF / total_res
    wBRAM = aBRAM / total_res
    wDSP = aDSP / total_res
    return (wLUT * LUT + wFF * FF + wBRAM * BRAM + wDSP * DSP) / total_res

  def display_info(self):
    print(f"[low: {self.low}, high: {self.high}, count: {self.count}, distinct count: {self.distinct_count}]")

class CoarseGrainedCountingBloomBucket(Bucket):

  seeds = [0x92d6a354, 0x8bf65351, 0x960b7a1f, 0x9d670b00, 0xb32d6bd1]

  resources_S = (2665, 1325, 0, 24) # (LUTs, FFs, BRAM, DSPs) for 2 ** 5
  resources_M = (16438, 8493, 0, 24) # (LUTs, FFs, BRAM, DSPs) for 2 ** 8
  resources_L = (66979, 33069, 0, 24) # (LUTs, FFs, BRAM, DSPs) for 2 ** 10

  latency = 1 # clock cycles

  def __init__(self, num_hashes, filter_size_bits):
    super().__init__()
    self.distinct_count = 0
    self.is_configured = False
    self.num_hashes = num_hashes
    self.filter_size_bits = filter_size_bits
    self.filter_size = 2 ** filter_size_bits
    self.counting_bloom_filter = [0] * self.filter_size

    if filter_size_bits <= 5:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_S
    elif filter_size_bits <= 8:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_M
    else:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_L

  def config(self, low, high):
    if self.is_configured == False:
      self.low = low
      self.high = high
      self.count = 0
      self.distinct_count = 0
      self.is_configured = True
      self.counting_bloom_filter = [0] * self.filter_size

  def update(self, val):
    if self.is_configured == True and val >= self.low and val < self.high:
      self.count += 1

      query = True

      for i in range(self.num_hashes):
        h = murmur3(val, self.seeds[i]) % self.filter_size

        if self.counting_bloom_filter[h] == 0:
          query = False

        self.counting_bloom_filter[h] += 1

      if query == False:
        self.distinct_count += 1

  def read(self, val):
    if self.is_configured == True and val >= self.low and val < self.high:
      min_count = self.counting_bloom_filter[murmur3(val, self.seeds[0]) % self.filter_size]
      for i in range(1, self.num_hashes):
        h = murmur3(val, self.seeds[i]) % self.filter_size

        if self.counting_bloom_filter[h] < min_count:
          min_count = self.counting_bloom_filter[h]

      return min_count

    else:
      return 0

  def get_resource_consumption(self):
    return (self.LUT, self.FF, self.BRAM, self.DSP)

  @classmethod
  def get_resources_of_bucket(cls, size):
    if size == 'S':
      return cls.resources_S
    elif size == 'M':
      return cls.resources_M
    else:
      return cls.resources_L

  @classmethod
  def create_default_bucket(cls, size):
    if size == 'S':
      return CoarseGrainedCountingBloomBucket(3, 5)
    elif size == 'M':
      return CoarseGrainedCountingBloomBucket(3, 8)
    else:
      return CoarseGrainedCountingBloomBucket(3, 10)

  def avg_resource_usage(self, available_budget=None):
    if available_budget == None:
      return (self.LUT + self.FF + self.BRAM + self.DSP) / 4
    else:
      normalized_usage = tuple(a / b for a, b in zip(self.get_resource_consumption(), available_budget))
      nLUT, nFF, nBRAM, nDSP = normalized_usage
      return (nLUT + nFF + nBRAM + nDSP) / 4

  def weighted_resource_usage(self, available_budget):
    LUT, FF, BRAM, DSP = self.get_resource_consumption()
    aLUT, aFF, aBRAM, aDSP = available_budget
    total_res = aLUT + aFF + aBRAM + aDSP
    wLUT = aLUT / total_res
    wFF = aFF / total_res
    wBRAM = aBRAM / total_res
    wDSP = aDSP / total_res
    return (wLUT * LUT + wFF * FF + wBRAM * BRAM + wDSP * DSP) / total_res

  def display_info(self):
    print(f"[low: {self.low}, high: {self.high}, count: {self.count}, distinct count: {self.distinct_count}]")

def next_power_of_2(n):
  n = n - 1
  n -= 1
  n |= n >> 1
  n |= n >> 2
  n |= n >> 4
  n |= n >> 8
  n |= n >> 16
  n += 1
  return n

class FineGrainedBucket(Bucket):

  resources_S = (678, 540, 0.5, 0) # (LUTs, FFs, BRAM, DSPs) for 2 ** 7 = 128
  resources_M = (678, 540, 2, 0) # (LUTs, FFs, BRAM, DSPs) for 2 ** 11 = 2K
  resources_L = (678, 540, 7.5, 0) # (LUTs, FFs, BRAM, DSPs) for 2 ** 13 = 8K

  latency = 4 # clock cycles

  def __init__(self, num_sub_buckets_bits):
    super().__init__()
    self.msb_pos = 0
    self.num_sub_buckets_bits = num_sub_buckets_bits
    self.num_sub_buckets = 2 ** num_sub_buckets_bits
    self.is_configured = False
    self.histogram = [0] * self.num_sub_buckets

    if num_sub_buckets_bits <= 7:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_S
    elif num_sub_buckets_bits <= 11:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_M
    else:
      (self.LUT, self.FF, self.BRAM, self.DSP) = self.resources_L

  def config(self, low, high):
    if self.is_configured == False:
      self.low = low
      self.high = high
      self.msb_pos = int(math.log2(next_power_of_2(high - low)))
      self.is_configured = True

  def compute_address(self, val):
    if self.is_configured == True and val >= self.low and val < self.high:
      return min(self.num_sub_buckets - 1, (val - self.low) >> (max(self.msb_pos - self.num_sub_buckets_bits, 0)))
    return 0

  def update(self, val):
    if self.is_configured == True and val >= self.low and val < self.high:
      addr = self.compute_address(val)
      if addr >= self.num_sub_buckets:
        print(self.low, self.high, self.msb_pos, self.num_sub_buckets, addr, val)
      self.histogram[addr] += 1
      self.count += 1

  def read(self, val):
    if self.is_configured == True and val >= self.low and val < self.high:
      addr = self.compute_address(val)
      return self.histogram[addr]
    else:
      return 0

  def get_resource_consumption(self):
    return (self.LUT, self.FF, self.BRAM, self.DSP)

  @classmethod
  def get_resources_of_bucket(cls, size):
    if size == 'S':
      return cls.resources_S
    elif size == 'M':
      return cls.resources_M
    else:
      return cls.resources_L

  @classmethod
  def create_default_bucket(cls, size):
    if size == 'S':
      return FineGrainedBucket(7)
    elif size == 'M':
      return FineGrainedBucket(11)
    else:
      return FineGrainedBucket(13)

  def avg_resource_usage(self, available_budget=None):
    if available_budget == None:
      return (self.LUT + self.FF + self.BRAM + self.DSP) / 4
    else:
      normalized_usage = tuple(a / b for a, b in zip(self.get_resource_consumption(), available_budget))
      nLUT, nFF, nBRAM, nDSP = normalized_usage
      return (nLUT + nFF + nBRAM + nDSP) / 4

  def weighted_resource_usage(self, available_budget):
    LUT, FF, BRAM, DSP = self.get_resource_consumption()
    aLUT, aFF, aBRAM, aDSP = available_budget
    total_res = aLUT + aFF + aBRAM + aDSP
    wLUT = aLUT / total_res
    wFF = aFF / total_res
    wBRAM = aBRAM / total_res
    wDSP = aDSP / total_res
    return (wLUT * LUT + wFF * FF + wBRAM * BRAM + wDSP * DSP) / total_res

  def display_info(self):
    print(f"[low: {self.low}, high: {self.high}, count: {self.count}]")
    for i in range(len(self.histogram)):
      print(f"count({i}) = {self.histogram[i]}")

class HybridHistogram:
  def __init__(self, min, max):
    self.buckets = []
    self.min = min
    self.max = max

  def add_bucket(self, bucket):
    if isinstance(bucket, Bucket):
      self.buckets.append(bucket)
    else:
      raise TypeError("Bucket must be an instance of Bucket class or its subclasses...")

  def remove_bucket(self, bucket):
    if isinstance(bucket, Bucket) and bucket in self.buckets:
      self.buckets.remove(bucket)
    else:
      raise TypeError("Bucket must be an instance of Bucket class or its subclasses...")

  def update(self, val):
    for bucket in self.buckets:
      bucket.update(val)

  def read(self, val):
    for bucket in self.buckets:
      result = bucket.read(val)
      if result > 0:
        return result
    return 0

  def get_resource_consumption(self):
    total_LUTs = 0
    total_FFs = 0
    total_BRAM = 0
    total_DSPs = 0

    for bucket in self.buckets:
      LUTs, FFs, BRAM, DSPs = bucket.get_resource_consumption()
      total_LUTs += LUTs
      total_FFs += FFs
      total_BRAM += BRAM
      total_DSPs += DSPs

    return (total_LUTs, total_FFs, total_BRAM, total_DSPs)

  def weighted_resource_usage(self, available_budget):
    LUT, FF, BRAM, DSP = self.get_resource_consumption()
    aLUT, aFF, aBRAM, aDSP = available_budget
    total_res = aLUT + aFF + aBRAM + aDSP
    wLUT = aLUT / total_res
    wFF = aFF / total_res
    wBRAM = aBRAM / total_res
    wDSP = aDSP / total_res
    return (wLUT * LUT + wFF * FF + wBRAM * BRAM + wDSP * DSP) / total_res

  def get_latency(self):
    total_latency = 0
    for bucket in self.buckets:
      total_latency += bucket.latency
    return total_latency

  def as_list(self):
    histo_list = []
    for x in range(self.min, self.max):
      histo_list.append(self.read(x))
    return histo_list

  def print_all_frequencies(self):
    histo_list = self.as_list()
    for i in range(self.min, self.max):
      print(f"{i} : {histo_list[i - self.min]}")

  def display_info(self):
    for bucket in self.buckets:
      bucket.display_info()

def get_max_buckets_in_budget(res_budget, bucket_type, size):
  av_LUT, av_FF, av_BRAM, av_DSP = res_budget
  b_LUT, b_FF, b_BRAM, b_DSP = bucket_type.get_resources_of_bucket(size)

  if b_LUT != 0:
    max_buck_LUT = av_LUT / b_LUT
  else:
    max_buck_LUT = float('inf')

  if b_FF != 0:
    max_buck_FF = av_FF / b_FF
  else:
    max_buck_FF = float('inf')

  if b_BRAM != 0:
    max_buck_BRAM = av_BRAM / b_BRAM
  else:
    max_buck_BRAM = float('inf')

  if b_DSP != 0:
    max_buck_DSP = av_DSP / b_DSP
  else:
    max_buck_DSP = float('inf')


  return int(min(max_buck_LUT, max_buck_FF, max_buck_BRAM, max_buck_DSP))

def compute_per_value_histogram(data):
  ground_truth = [0] * (max(data) + 1 - min(data))
  for d in data:
    ground_truth[d - min(data)] += 1

  return ground_truth

def mse(histo, ground_truth_histo):
  mse = 0
  for value in range(histo.min, histo.max):
    mse += (histo.read(value) - ground_truth_histo[value - histo.min]) ** 2
  return mse / (histo.max - histo.min)

def mae(histo, ground_truth_histo):
  mae = 0
  for value in range(histo.min, histo.max):
    mae += abs(histo.read(value) - ground_truth_histo[value - histo.min])
  return mae / (histo.max - histo.min)

def rmse(histo, ground_truth_histo):
  rmse = 0
  for value in range(histo.min, histo.max):
    # if (histo.read(value) - ground_truth_histo[value - histo.min]) ** 2 != 0:
    #   print(f"val = {value}: ground truth = {ground_truth_histo[value - histo.min]}, approx = {histo.read(value)}")
    rmse += (histo.read(value) - ground_truth_histo[value - histo.min]) ** 2
  return math.sqrt(rmse / (histo.max - histo.min))

def mse_of_bucket(bucket, ground_truth_histo, min_val):
  mse = 0
  for value in range(bucket.low, bucket.high):
    mse += (bucket.read(value) - ground_truth_histo[value - min_val]) ** 2
  return mse / (bucket.high - bucket.low)

def mae_of_bucket(bucket, ground_truth_histo, min_val):
  mae = 0
  for value in range(bucket.low, bucket.high):
    mae += abs(bucket.read(value) - ground_truth_histo[value - min_val])
  return mae / (bucket.high - bucket.low)

def rmse_of_bucket(bucket, ground_truth_histo, min_val):
  rmse = 0
  for value in range(bucket.low, bucket.high):
    rmse += (bucket.read(value) - ground_truth_histo[value - min_val]) ** 2
  return math.sqrt(rmse / (bucket.high - bucket.low))

def mse_per_bucket(histo, ground_truth_histo):
  mse_list = []
  for bucket in histo.buckets:
    mse_list.append(mse_of_bucket(bucket, ground_truth_histo, histo.min))
  return mse_list

def mae_per_bucket(histo, ground_truth_histo):
  mae_list = []
  for bucket in histo.buckets:
    mae_list.append(mae_of_bucket(bucket, ground_truth_histo, histo.min))
  return mae_list

def rmse_per_bucket(histo, ground_truth_histo):
  rmse_list = []
  for bucket in histo.buckets:
    rmse_list.append(rmse_of_bucket(bucket, ground_truth_histo, histo.min))
  return rmse_list

def plot_histogram(histo, ground_truth, min):
  xs = [x for x in range(min, min + len(ground_truth))]
  plt.plot(xs, ground_truth, color="springgreen", label="Ground truth", alpha=0.5)
  plt.plot(xs, histo.as_list(), color="fuchsia", label="FPGA histo", alpha=0.5)
  plt.legend()
  plt.show()

def histogram_configuration(data, ground_truth_histo, num_buckets, strategy):
  min_val = min(data)
  max_val = max(data)

  if strategy == 'depth-count':
    total_count = sum(ground_truth_histo)
    bucket_max_count = total_count // num_buckets

    # print(f"total_count = {total_count}")
    # print(f"num buckets = {num_buckets}")
    # print(f"bucket_max_count = {bucket_max_count}")
    # print(f"min = {min_val}")
    # print(f"max = {max_val}")

    current_count = 0
    low = min_val
    high = low + 1

    buckets = []
    dif = 0
    for i in range(num_buckets):
      index = low
      first = True
      while index < max_val + 1 and (current_count + dif < bucket_max_count or first == True):
        current_count += ground_truth_histo[index - min_val]
        index += 1
        first = False

      if current_count > bucket_max_count:
        dif += current_count - bucket_max_count
      else:
        dif = 0


      high = index

      if i == num_buckets - 1:
        while (high < max_val + 1):
          current_count += ground_truth_histo[high - min_val]
          high += 1
      buckets.append((low, high, current_count))

      if high == max_val + 1:
        break

      low = high
      high += 1
      current_count = 0

    return buckets


  elif strategy == 'depth-distinct':
    total_distinct = 0

    for h in ground_truth_histo:
      if h > 0:
        total_distinct += 1

    bucket_max_distinct = total_distinct // num_buckets

    # print(f"total_distinct = {total_distinct}")
    # print(f"num buckets = {num_buckets}")
    # print(f"bucket_max_dist = {bucket_max_distinct}")

    current_distinct = 0
    low = min_val
    high = low + 1

    buckets = []
    dif = 0
    for i in range(num_buckets):
      index = low
      while index < max_val + 1 and current_distinct + dif < bucket_max_distinct:
        if ground_truth_histo[index - min_val]:
            current_distinct += 1
        index += 1

      if current_distinct > bucket_max_distinct:
        dif += current_distinct - bucket_max_distinct
      else:
        dif = 0

      high = index

      if i == num_buckets - 1:
        while (high < max_val + 1):
          if ground_truth_histo[high - min_val]:
            current_distinct += 1
          high += 1


      buckets.append((low, high, current_distinct))

      if high == max_val + 1:
        break

      low = high
      high += 1
      current_distinct = 0

    return buckets

  elif strategy == 'width':
    range_size = (max_val - min_val) // num_buckets
    rem = (max_val - min_val) % num_buckets

    # print(f"range size = {range_size}")
    # print(f"rem = {rem}")

    bucket_count = 0
    current_count = 0
    low = min_val

    if rem > 0:
      high = low + range_size + 1
      rem -= 1
    else:
      high = low + range_size

    buckets = []

    for i in range(num_buckets):
      for j in range(low, high):
        current_count += ground_truth_histo[j - min_val]

      if i == num_buckets - 1:
        while (high < max_val + 1):
          current_count += ground_truth_histo[high - min_val]
          high += 1
        # print(f"low = {low}")
        # print(f"high = {high}")


      buckets.append((low, high, current_count))

      low = high

      if rem > 0:
        rem -= 1
        high += range_size + 1
      else:
        high += range_size

      current_count = 0

    return buckets

  else:
    return []

def construct_candidates(data, ground_truth_histo, resource_budget, num_buckets, split_strategy, bit):
  avLUT, avFF, avBRAM, avDSP = resource_budget

  bucket_types = [CoarseGrainedSimpleBucket, CoarseGrainedDistinctBucket, CoarseGrainedBloomBucket, CoarseGrainedCountingBloomBucket, FineGrainedBucket]
  sizes = ['S', 'M', 'L']
  buckets_config = histogram_configuration(data, ground_truth_histo, num_buckets, split_strategy)

  if bit == True and len(buckets_config) < num_buckets:
    return []

  ordered_candidate_buckets = []

  min_data = min(data)

  for config in buckets_config:
    low, high, stat = config

    candidate_buckets = []

    for bucket_type in bucket_types:
      if high - low < 50 and bucket_type == FineGrainedBucket or high - low < 50 and bucket_type == CoarseGrainedCountingBloomBucket:
        continue

      for size in sizes:
        bucket = bucket_type.create_default_bucket(size)
        bucket.config(low, high)

        for sample in range(low, high):
          ground_truth_count = ground_truth_histo[sample - min_data]

          while ground_truth_count > 0:
            bucket.update(sample)
            ground_truth_count -= 1

        err = mse_of_bucket(bucket, ground_truth_histo, min_data)
        LUT, FF, BRAM, DSP = bucket.get_resource_consumption()
        if LUT > avLUT or FF > avFF or BRAM > avBRAM or DSP > avDSP:
          continue

        candidate_buckets.append((bucket, err, LUT, FF, BRAM, DSP))

    candidate_buckets.sort(key=lambda x: (x[1], x[2], x[3], x[4], x[5]))
    ordered_candidate_buckets.append(candidate_buckets)


  return ordered_candidate_buckets

def greedy_min_error_histogram(candidate_buckets, resource_budget, eps=10, opt_resources=False):
  available_resources = resource_budget

  # print(candidate_buckets)
  selected_buckets = []

  for candidate_list in candidate_buckets:
    chosen_bucket = None
    for candidate in candidate_list:
      candidate_bucket, candidate_err, candidate_LUT, candidate_FF, candidate_BRAM, candidate_DSP = candidate
      updated_available_resources = tuple(a - b for a, b in zip(available_resources, candidate_bucket.get_resource_consumption()))
      if all(r >= 0 for r in updated_available_resources): # and candidate_err < eps:
        available_resources = updated_available_resources
        chosen_bucket = candidate
        selected_buckets.append(candidate)
        break

    if chosen_bucket is None:
      print("Out of resources...")
      selected_buckets = None
      break

  return selected_buckets

def greedy_avg_res_histogram(candidate_buckets, resource_budget, eps=10000, opt_resources=False):
  N = len(candidate_buckets)

  avgLUT, avgFF, avgBRAM, avgDSP = resource_budget
  avgLUT //= N
  avgFF //= N
  avgBRAM //= N
  avgDSP //= N

  available_resources = (avgLUT, avgFF, avgBRAM, avgDSP)
  avr = (avgLUT, avgFF, avgBRAM, avgDSP)
  # print(available_resources)
  # print(resource_budget)

  # print(candidate_buckets)
  selected_buckets = []

  count = 0

  unused_res = (0, 0, 0, 0)

  for candidate_list in candidate_buckets:
    chosen_bucket = None
    # print(candidate_list[0][0].low, candidate_list[0][0].high)
    available_resources = tuple(a + b  for a, b in zip(avr, unused_res))
    for candidate in candidate_list:
      # print(candidate)
      candidate_bucket, candidate_err, candidate_LUT, candidate_FF, candidate_BRAM, candidate_DSP = candidate
      unused_res = tuple(a - b for a, b in zip(available_resources, candidate_bucket.get_resource_consumption()))
      if all(r >= 0 for r in unused_res) : #and candidate_err < eps
        chosen_bucket = candidate
        selected_buckets.append(candidate)
        count += 1
        break

    if chosen_bucket is None:
      print("Out of resources...")
      selected_buckets = None
      break

  return selected_buckets

def simulated_annealing_histogram(candidate_buckets, resource_budget, first_sol='first', alpha=0.5, initial_temp=1000, cooling_rate=0.995, max_iterations=100000):
    max_LUT, max_FF, max_BRAM, max_DSP = resource_budget

    def calculate_cost(error, LUTs, FFs, BRAMs, DSPs, LUT_weight, FF_weight, BRAM_weight, DSP_weight):
      total_resources = LUTs + FFs + BRAMs + DSPs
      resource_cost = (LUT_weight * LUTs + FF_weight * FFs + BRAM_weight * BRAMs + DSP_weight * DSPs) / total_resources
      return alpha * error + (1 - alpha) * resource_cost

    total_resources = max_LUT + max_FF + max_BRAM + max_DSP
    LUT_weight = max_LUT / total_resources
    FF_weight = max_FF / total_resources
    BRAM_weight = max_BRAM / total_resources
    DSP_weight = max_DSP / total_resources

    n = len(candidate_buckets)

    if first_sol == 'first':
      current_solution = [candidates[0] for candidates in candidate_buckets]
    elif first_sol == 'last':
      current_solution = [candidates[-1] for candidates in candidate_buckets]
    elif first_sol == 'middle':
      current_solution = [candidates[len(candidates) // 2] for candidates in candidate_buckets]
    else:
      current_solution = [random.choice(candidates) for candidates in candidate_buckets]

    def calculate_solution_cost(solution):
      error = 0
      total_LUTs = total_FFs = total_BRAMs = total_DSPs = 0
      for i in range(n):
          _, e, LUTs, FFs, BRAMs, DSPs = solution[i]
          error += e
          total_LUTs += LUTs
          total_FFs += FFs
          total_BRAMs += BRAMs
          total_DSPs += DSPs

      if total_LUTs > max_LUT or total_FFs > max_FF or total_BRAMs > max_BRAM or total_DSPs > max_DSP:
          return float('inf')

      return calculate_cost(error, total_LUTs, total_FFs, total_BRAMs, total_DSPs, LUT_weight, FF_weight, BRAM_weight, DSP_weight)

    current_cost = calculate_solution_cost(current_solution)

    best_solution = current_solution
    best_cost = current_cost

    temperature = initial_temp
    iteration = 0

    while temperature > 1e-3 and iteration < max_iterations:
      iteration += 1

      new_solution = current_solution[:]
      range_idx = random.randint(0, n - 1)
      candidate_idx = random.randint(0, len(candidate_buckets[range_idx]) - 1)
      new_solution[range_idx] = candidate_buckets[range_idx][candidate_idx]

      new_cost = calculate_solution_cost(new_solution)

      if new_cost < current_cost or random.random() < math.exp((current_cost - new_cost) / temperature):
          current_solution = new_solution
          current_cost = new_cost

          if new_cost < best_cost:
              best_solution = new_solution
              best_cost = new_cost

      temperature *= cooling_rate

    # print(f"best cost = {best_cost}")
    if best_cost == float('inf'):
        return None
    return best_solution

def read_csv_file(file_path):
  with open(file_path, mode='r') as file:
    csv_reader = csv.reader(file)
    data_list = []
    for row in csv_reader:
        data_list.append(int(row[1]))
    return data_list

def run(data_path, resource_budget, num_buckets, algorithm, split_strategy):
  data = read_csv_file(data_path)
  ground_truth_histo = compute_per_value_histogram(data)

  min_val = min(data)
  max_val = max(data)
  print(min_val, max_val)


  candidate_buckets = construct_candidates(data, ground_truth_histo, resource_budget, num_buckets, split_strategy, False)
  candidate_buckets.sort(key=lambda candidates: (candidates[0][0].high - candidates[0][0].low))

  # for c in candidate_buckets:
  #   print(c[0][0].low, c[0][0].high)

  selected_buckets = algorithm(candidate_buckets, resource_budget)
  selected_buckets.sort(key=lambda selected: (selected[0].low))

  if selected_buckets is None:
    print("Out of resources...")
    return

  print("Selected Buckets: ")
  for bucket in selected_buckets:
    print(bucket[0].low, bucket[0].high, bucket)

  histo = HybridHistogram(min_val, max_val + 1)
  for b in selected_buckets:
    histo.add_bucket(b[0])

  err = rmse(histo, ground_truth_histo)
  print(err)
  print(rmse_per_bucket(histo, ground_truth_histo))
  plot_histogram(histo, ground_truth_histo, min_val)

def run_all(data_path, outputs_path, resource_budget, max_num_buckets):
  data = read_csv_file(data_path)
  ground_truth_histo = compute_per_value_histogram(data)

  min_val = min(data)
  max_val = max(data)
  print(min_val, max_val)

  with open(outputs_path, mode="w", encoding="utf-8") as file:

    file.write(
      "max # buckets" + "," +
      "actual # buckets" + "," +
      "ground truth split strategy" + "," +
      "algorithm" + "_" + "[first solution construction]" + "," +
      "overall err" + "," +
      "weighted res. consumption" + "," +
      "latency (cycles)" + "," +
      "LUTs (%)" + "," +
      "FFs (%)" + "," +
      "BRAM (%)" + "," +
      "DSPs (%)" + "," +
      "(bucket type : per bucket err)" + "\n"
    )

    for num_buckets in range(1, max_num_buckets + 1):
      print(f"num buckets = {num_buckets}")
      for split_strategy in ['depth-count', 'depth-distinct', 'width']:
        candidate_buckets = construct_candidates(data, ground_truth_histo, resource_budget, num_buckets, split_strategy, True)
        if candidate_buckets == []:
          continue

        candidate_buckets.sort(key=lambda candidates: (candidates[0][0].high - candidates[0][0].low))

        for algorithm in [greedy_min_error_histogram, greedy_avg_res_histogram, simulated_annealing_histogram]:

          # for c in candidate_buckets:
          #   print(c[0][0].low, c[0][0].high)

          if algorithm == simulated_annealing_histogram:
            for first_sol in ['first', 'middle', 'last', 'random']:
              selected_buckets = algorithm(candidate_buckets, resource_budget, first_sol)

              if selected_buckets is None:
                print("Out of resources...")
              else:
                selected_buckets.sort(key=lambda selected: (selected[0].low))
                histo = HybridHistogram(min_val, max_val + 1)
                for b in selected_buckets:
                  histo.add_bucket(b[0])

                err = rmse(histo, ground_truth_histo)
                histo_res = histo.get_resource_consumption()

                buckets_str = ''
                for b in selected_buckets:
                  buckets_str += '(' + str(type(b[0])) + ' : ' + str(rmse_of_bucket(b[0], ground_truth_histo, min_val)) + ') '

                file.write(
                  str(num_buckets) + "," +
                  str(len(selected_buckets)) + "," +
                  split_strategy + "," +
                  algorithm.__name__ + "_" + first_sol + "," +
                  str(err) + "," +
                  str(histo.weighted_resource_usage(resource_budget)) + "," +
                  str(histo.get_latency()) + "," +
                  str(histo_res[0] / resource_budget[0] * 100) + "," +
                  str(histo_res[1] / resource_budget[1] * 100) + "," +
                  str(histo_res[2] / resource_budget[2] * 100) + "," +
                  str(histo_res[3] / resource_budget[3] * 100) + "," +
                  buckets_str + "\n"
                )

          else:
            selected_buckets = algorithm(candidate_buckets, resource_budget)

            if selected_buckets is None:
              print("Out of resources...")
            else:
              selected_buckets.sort(key=lambda selected: (selected[0].low))
              histo = HybridHistogram(min_val, max_val + 1)
              for b in selected_buckets:
                histo.add_bucket(b[0])

              err = rmse(histo, ground_truth_histo)
              histo_res = histo.get_resource_consumption()

              buckets_str = ''
              for b in selected_buckets:
                buckets_str += '(' + str(type(b[0])) + ' : ' + str(rmse_of_bucket(b[0], ground_truth_histo, min_val)) + ') '

              file.write(
                str(num_buckets) + "," +
                str(len(selected_buckets)) + "," +
                split_strategy + "," +
                algorithm.__name__ + "," +
                str(err) + "," +
                str(histo.weighted_resource_usage(resource_budget)) + "," +
                str(histo.get_latency()) + "," +
                str(histo_res[0] / resource_budget[0] * 100) + "," +
                str(histo_res[1] / resource_budget[1] * 100) + "," +
                str(histo_res[2] / resource_budget[2] * 100) + "," +
                str(histo_res[3] / resource_budget[3] * 100) + "," +
                buckets_str + "\n"
              )

from concurrent.futures import ProcessPoolExecutor, as_completed

def process_combination(num_buckets, split_strategy, data, ground_truth_histo, resource_budget, min_val, max_val):
    results = []
    candidate_buckets = construct_candidates(data, ground_truth_histo, resource_budget, num_buckets, split_strategy, True)
    if not candidate_buckets:
        return results

    candidate_buckets.sort(key=lambda candidates: (candidates[0][0].high - candidates[0][0].low))

    for algorithm in [greedy_min_error_histogram, greedy_avg_res_histogram, simulated_annealing_histogram]:
        if algorithm == simulated_annealing_histogram:
            for first_sol in ['first', 'middle', 'last', 'random']:
                selected_buckets = algorithm(candidate_buckets, resource_budget, first_sol)
                if selected_buckets:
                    results.append(process_selected_buckets(
                        num_buckets, split_strategy, f"{algorithm.__name__}_{first_sol}",
                        selected_buckets, ground_truth_histo, min_val, max_val, resource_budget))
        else:
            selected_buckets = algorithm(candidate_buckets, resource_budget)
            if selected_buckets:
                results.append(process_selected_buckets(
                    num_buckets, split_strategy, algorithm.__name__,
                    selected_buckets, ground_truth_histo, min_val, max_val, resource_budget))
    return results

def process_selected_buckets(num_buckets, split_strategy, algorithm_name, selected_buckets, ground_truth_histo, min_val, max_val, resource_budget):
    selected_buckets.sort(key=lambda selected: (selected[0].low))
    histo = HybridHistogram(min_val, max_val + 1)
    for b in selected_buckets:
        histo.add_bucket(b[0])

    err = rmse(histo, ground_truth_histo)
    histo_res = histo.get_resource_consumption()
    buckets_str = ' '.join(
        f"({type(b[0])} : {rmse_of_bucket(b[0], ground_truth_histo, min_val)})"
        for b in selected_buckets
    )
    return (
        num_buckets, len(selected_buckets), split_strategy, algorithm_name,
        err, histo.weighted_resource_usage(resource_budget), histo.get_latency(),
        histo_res[0] / resource_budget[0] * 100, histo_res[1] / resource_budget[1] * 100,
        histo_res[2] / resource_budget[2] * 100, histo_res[3] / resource_budget[3] * 100, buckets_str
    )

def run_all_parallel(data_path, outputs_path, resource_budget, max_num_buckets):
    data = read_csv_file(data_path)
    ground_truth_histo = compute_per_value_histogram(data)
    min_val, max_val = min(data), max(data)

    with open(outputs_path, mode="w", encoding="utf-8") as file:
        file.write(
            "max # buckets,actual # buckets,ground truth split strategy,algorithm,"
            "overall err,weighted res. consumption,latency (cycles),LUTs (%),FFs (%),BRAM (%),DSPs (%),(bucket type : per bucket err)\n"
        )

        tasks = []
        with ProcessPoolExecutor() as executor:
            for num_buckets in range(1, max_num_buckets + 1):
                for split_strategy in ['depth-count', 'depth-distinct', 'width']:
                    tasks.append(executor.submit(process_combination, num_buckets, split_strategy, data, ground_truth_histo, resource_budget, min_val, max_val))

            for future in as_completed(tasks):
                for result in future.result():
                    file.write(','.join(map(str, result)) + '\n')

from concurrent.futures import ProcessPoolExecutor, as_completed
from itertools import product

def process_task_group(task_group, data, ground_truth_histo, resource_budget, min_val, max_val):
    results = []
    for num_buckets, split_strategy in task_group:
        print(num_buckets)
        results.extend(process_combination(
            num_buckets, split_strategy, data, ground_truth_histo,
            resource_budget, min_val, max_val
        ))
    return results

def run_all_parallel2(data_path, outputs_path, resource_budget, max_num_buckets, chunk_size=15):
    data = read_csv_file(data_path)
    ground_truth_histo = compute_per_value_histogram(data)
    min_val, max_val = min(data), max(data)

    all_tasks = list(product(range(1, max_num_buckets + 1), ['depth-count', 'depth-distinct', 'width']))
    chunks = [all_tasks[i:i + chunk_size] for i in range(0, len(all_tasks), chunk_size)]

    results = []
    with ProcessPoolExecutor() as executor:
        futures = [executor.submit(process_task_group, chunk, data, ground_truth_histo, resource_budget, min_val, max_val)
                   for chunk in chunks]

        for future in as_completed(futures):
            results.extend(future.result())

    with open(outputs_path, mode="w", encoding="utf-8") as file:
        file.write(
            "max # buckets,actual # buckets,ground truth split strategy,algorithm,"
            "overall err,weighted res. consumption,latency (cycles),LUTs (%),FFs (%),BRAM (%),DSPs (%),(bucket type : per bucket err)\n"
        )
        for result in results:
            file.write(','.join(map(str, result)) + '\n')

# data_path = './Data/heatdata_small.csv'
# data_path = './Data/humidity_large_values.csv'
# data_path = './Data/vineyard_data_small.csv'
# data_path = './Data/vineyard_data_2000.csv'
# data_path = './Data/pm_data_times_100.csv'
# data_path = './Data/humidity_dataset.csv'
# data_path = './Data/10m_tunnel_phy_4000.csv'
# data_path = './Data/alcohol_sales.csv'
# data_path = './Data/engine_lub_oil_first2000_x1000000.csv'
# data_path = './Data/engine_lub_oil_temp_first2000_x100000.csv'
# data_path = './Data/elevator_predictive_maintenance_s4_x1000.csv'
data_path = './Data/10m_vineyard_phy_first2000_x100000.csv'

zynq_budget = (230400, 460800, 312, 1728)
basys3_budget = (20800, 41600, 50, 90)

outputs_path = './Outputs/results_10m_vineyard_phy_first2000_x100000_up_to_26.csv'
# outputs_path = './Outputs/results_humidity_small_values.csv'

# run(data_path, basys3_budget, 1, greedy_avg_res_histogram, 'width')

n = len(read_csv_file(data_path))
k = math.ceil(2 * (n ** (1 / 3)))
print(f"k = {k}")
run_all_parallel2(data_path, outputs_path, basys3_budget, k, 15)