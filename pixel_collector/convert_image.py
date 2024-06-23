import numpy as np
from PIL import Image
import argparse

def hex_to_int(hex_str):
    """Convert a hex string to an integer. Handle 'x' as a max value."""
    if ('x' in hex_str) or ('X' in hex_str):
        return 0xFFFF  # Substitute 'x' with 0xFFFF to make it very visible
    return int(hex_str, 16)

def read_hex_file(filename, width, height):
    """Read a hex file containing image data in either matrix or list format."""
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    # Check if the input is formatted as a matrix
    if len(lines) == height and all(len(line.strip().split()) == width for line in lines):
        return read_matrix_format(lines, width, height)
    else:
        return read_list_format(lines, width, height)

def read_matrix_format(lines, width, height):
    """Read data from a file formatted as a matrix."""
    image_data = np.zeros((height, width), dtype=np.uint16)  # Assuming the data is 16-bit

    for i, line in enumerate(lines):
        hex_values = line.strip().split()
        for j, hex_value in enumerate(hex_values):
            image_data[i, j] = hex_to_int(hex_value)

    return image_data

def read_list_format(lines, width, height):
    """Read data from a file formatted as a list."""
    image_data = np.zeros((height, width), dtype=np.uint16)  # Assuming the data is 16-bit

    # Join all lines into a single string and split
    hex_values = ' '.join(lines).strip().split()

    if len(hex_values) != width * height:
        raise ValueError(f"Expected {width * height} values, but found {len(hex_values)}.")

    for idx, hex_value in enumerate(hex_values):
        row = idx // width
        col = idx % width
        image_data[row, col] = hex_to_int(hex_value)

    return image_data

def normalize_to_8bit(image_data):
    """Normalize 16-bit image data to 8-bit grayscale values."""
    normalized_data = (image_data / np.max(image_data) * 255).astype(np.uint8)
    return normalized_data

def save_image(image_data, output_filename):
    """Save the image data as a grayscale image."""
    image = Image.fromarray(image_data, mode='L')
    image.save(output_filename)

def main(input_filename, output_filename, image_width, image_height):
    # Read hex file and convert to image
    image_data = read_hex_file(input_filename, image_width, image_height)
    image_data_8bit = normalize_to_8bit(image_data)
    save_image(image_data_8bit, output_filename)
    print(f"Image saved to {output_filename}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert hex file to grayscale image.")
    parser.add_argument("input_file", help="Path to the input hex file")
    parser.add_argument("--output_file", default="output_image.png", help="Path to save the output image (default: output_image.png)")
    parser.add_argument("--width", type=int, default=640, help="Width of the image (default: 640)")
    parser.add_argument("--height", type=int, default=480, help="Height of the image (default: 480)")
    
    args = parser.parse_args()

    main(args.input_file, args.output_file, args.width, args.height)
