import cv2
import os

# Ask the user for input video file and output folder
VIDEO_FILE = input("Enter the path to the video file (e.g., input.mp4): ")
OUTPUT_FOLDER = input("Enter the folder name to save frames (e.g., frames/): ")

# Constants for frame extraction
DURATION = 2.5           # Duration to extract from the video in seconds
FRAME_RATE = 30          # Frames per second (FPS) of the video
EXPECTED_WIDTH = 640     # Expected width of the video
EXPECTED_HEIGHT = 480    # Expected height of the video

# Create the output folder if it doesn't exist
if not os.path.exists(OUTPUT_FOLDER):
    os.makedirs(OUTPUT_FOLDER)

# Open the video file using OpenCV
cap = cv2.VideoCapture(VIDEO_FILE)

# Check if the video file was opened successfully
if not cap.isOpened():
    print("Error: Could not open video file.")
    exit()

# Get the frame rate of the video
fps = cap.get(cv2.CAP_PROP_FPS)

# Check if the video FPS is 30
if fps != FRAME_RATE:
    print(f"Error: Video FPS is {fps}, expected {FRAME_RATE} FPS.")
    exit()

# Get the frame width and height
frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

# Check if the video resolution is 640p (exact 640x480 for this example)
if frame_width != EXPECTED_WIDTH or frame_height != EXPECTED_HEIGHT:
    print(f"Error: Video resolution is {frame_width}x{frame_height}, expected {EXPECTED_WIDTH}x{EXPECTED_HEIGHT}.")
    exit()

# Get the total number of frames in the video
total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

# Calculate the video duration in seconds
video_duration = total_frames / fps

# Check if the video duration is less than 2.5 seconds
if video_duration < DURATION:
    print(f"Error: Video is {video_duration} seconds long, but at least {DURATION} seconds is required.")
    exit()

# Get the total number of frames to extract based on the desired duration
frame_count = int(DURATION * FRAME_RATE)

# Loop through the frames of the video
frame_number = 0
while True:
    ret, frame = cap.read()

    if not ret or frame_number >= frame_count:
        break

    # Convert the frame to RGB (OpenCV uses BGR by default)
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    # Save the frame as a PPM image with zero-padded numbering
    ppm_filename = os.path.join(OUTPUT_FOLDER, f"frame{frame_number:02d}.ppm")
    with open(ppm_filename, 'wb') as f:
        # Write the PPM header
        f.write(b"P6\n")
        f.write(f"{frame.shape[1]} {frame.shape[0]}\n".encode())
        f.write(b"255\n")

        # Write the pixel data
        rgb_frame.tofile(f)

    print(f"Saved frame {frame_number:02d} as {ppm_filename}")
    frame_number += 1

# Release the video capture object
cap.release()

print(f"Extracted {frame_number} frames and saved them as PPM images.")