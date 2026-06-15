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
    size = int(sys.argv[1]) if len(sys.argv) > 1 else 1024 * 1024  # Default 1MB
    blob_talker = BlobTalker(size)
    rclpy.spin(blob_talker)
    blob_talker.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()
