import rclpy
from rclpy.node import Node
from std_msgs.msg import UInt8MultiArray
import sys

class BlobTalker(Node):
    def __init__(self, size_bytes):
        super().__init__('blob_talker')
        self.publisher_ = self.create_publisher(UInt8MultiArray, 'speed_test_topic', 10)
        self.get_logger().info(f'Publishing {size_bytes} bytes at 50Hz...')
        timer_period = 0.02  # 50Hz
        self.timer = self.create_timer(timer_period, self.timer_callback)
        self.msg = UInt8MultiArray()
        # Fill with actual non-zero data to ensure it's not compressed or optimized away by transport
        self.msg.data = [i % 256 for i in range(size_bytes)]
        self.get_logger().info('Buffer prepared.')

    def timer_callback(self):
        self.publisher_.publish(self.msg)

def main(args=None):
    rclpy.init(args=args)
    
    # Defaults: 4MB messages at 100Hz (~400MB/s target)
    size = int(sys.argv[1]) if len(sys.argv) > 1 else 4 * 1024 * 1024 
    freq = float(sys.argv[2]) if len(sys.argv) > 2 else 100.0
    
    blob_talker = BlobTalker(size)
    blob_talker.timer_period = 1.0 / freq
    blob_talker.timer.cancel() # Reset timer with new freq
    blob_talker.timer = blob_talker.create_timer(blob_talker.timer_period, blob_talker.timer_callback)
    
    blob_talker.get_logger().info(f'STRESS TEST: {size/(1024*1024):.2f} MB @ {freq} Hz (~{(size*freq)/(1024*1024):.2f} MB/s)')
    
    rclpy.spin(blob_talker)
    blob_talker.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()
