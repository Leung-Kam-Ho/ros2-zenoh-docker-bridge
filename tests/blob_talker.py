import rclpy
from rclpy.node import Node
from std_msgs.msg import UInt8MultiArray
import sys

from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

class BlobTalker(Node):
    def __init__(self, size_bytes):
        super().__init__('blob_talker')
        qos_profile = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=10
        )
        self.publisher_ = self.create_publisher(UInt8MultiArray, 'speed_test_topic', qos_profile)
        self.msg = UInt8MultiArray()
        # Use bytearray for performance
        self.msg.data = bytearray([i % 256 for i in range(min(size_bytes, 1024))]) * (size_bytes // min(size_bytes, 1024))
        self.get_logger().info(f'Talker initialized with {size_bytes} bytes.')

    def timer_callback(self):
        try:
            self.publisher_.publish(self.msg)
        except Exception as e:
            self.get_logger().error(f'Failed to publish: {e}')

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
