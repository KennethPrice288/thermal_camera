import numpy as np
import os

# Generate a test pattern (e.g., a gradient)
image_data = np.zeros((60, 80), dtype=np.uint16)
for i in range(60):
    for j in range(80):
        image_data[i, j] = ((i * 80 + j) % (2**14))  # Pattern logic

file_path = 'pattern_data.txt'
# Open the file in write mode
with open(file_path, 'w') as f:
    for row in image_data:
        for pixel in row:
            f.write(f'{pixel:04X}\n')  # Ensure 4 digits hex representation, 0-padded if necessary


print(f"pattern_data.hex created at {os.path.abspath(file_path)}.")
