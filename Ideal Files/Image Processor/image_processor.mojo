# File: image_processor.mojo
# Description: A high-performance image processor that uses Mojo's SIMD
# capabilities to accelerate a common computer vision task.

from python import Python
from memory import UnsafePointer
from simd import SIMD

# This function will be the high-performance kernel.
# It processes a chunk of pixels at a time using SIMD.
fn process_chunk_grayscale[nelts: Int](ptr: UnsafePointer[UInt8]):
    """
    Applies the luminosity method for grayscale conversion to a chunk of pixels.
    Formula: 0.299*R + 0.587*G + 0.114*B
    """
    # Load a vector of `nelts` pixels (nelts * 3 channels: R, G, B)
    var r = SIMD[DType.uint8, nelts]()
    var g = SIMD[DType.uint8, nelts]()
    var b = SIMD[DType.uint8, nelts]()

    # Assuming interleaved RGB data [R,G,B, R,G,B, ...]
    for i in range(nelts):
        r[i] = ptr.load(i * 3)
        g[i] = ptr.load(i * 3 + 1)
        b[i] = ptr.load(i * 3 + 2)

    # Perform the conversion using floating point for precision
    let r_float = r.cast[DType.float32]()
    let g_float = g.cast[DType.float32]()
    let b_float = b.cast[DType.float32]()

    let gray_float = r_float * 0.299 + g_float * 0.587 + b_float * 0.114
    let gray = gray_float.cast[DType.uint8]()

    # Write the grayscale value back to all three channels
    for i in range(nelts):
        let val = gray[i]
        ptr.store(i * 3, val)
        ptr.store(i * 3 + 1, val)
        ptr.store(i * 3 + 2, val)

fn main() raises:
    print("Starting high-performance image processing...")

    # Use Mojo's Python interop to load the image using familiar libraries
    let np = Python.import_module("numpy")
    let Image = Python.import_module("PIL.Image")

    # 1. Load the image
    print("Loading image 'input.png'...")
    let img_object = Image.open("input.png")
    var np_array = np.array(img_object)
    let data_ptr = UnsafePointer[UInt8](np_array.__array_interface__["data"][0])

    # 2. Get image dimensions
    let height = np_array.shape[0].to_int()
    let width = np_array.shape[1].to_int()
    let channels = np_array.shape[2].to_int()
    let total_pixels = height * width
    print(f"Image dimensions: {width}x{height}")

    if channels < 3:
        print("Image is not RGB. Exiting.")
        return

    # 3. Process the image data in parallel chunks
    print("Converting to grayscale using SIMD...")
    let simd_width = 16 # Process 16 pixels at a time
    for i in range(0, total_pixels, simd_width):
        process_chunk_grayscale[simd_width](data_ptr + i * 3)

    # 4. Save the resulting image
    print("Saving image 'output_grayscale.png'...")
    let result_img = Image.fromarray(np_array)
    result_img.save("output_grayscale.png")

    print("Processing complete.")
