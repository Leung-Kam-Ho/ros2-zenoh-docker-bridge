import rclpy
from rclpy.node import Node
from std_msgs.msg import UInt8MultiArray
import sys

from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy

class BlobTalker(Node):
    def __init__(self, size_bytes, freq):
        super().__init__('blob_talker')
        qos_profile = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=50
        )
        self.publisher_ = self.create_publisher(UInt8MultiArray, 'speed_test_topic', qos_profile)
        self.msg = UInt8MultiArray()
        # Use bytearray for performance
        pattern = [i % 256 for i in range(min(size_bytes, 1024))]
        self.msg.data = (pattern * (size_bytes // len(pattern) + 1))[:size_bytes]
        
        timer_period = 1.0 / freq
        self.timer = self.create_timer(timer_period, self.timer_callback)
        self.get_logger().info(f'Talker initialized: {size_bytes} bytes @ {freq} Hz')

    def timer_callback(self):
        try:
            self.publisher_.publish(self.msg)
            # print("Sent", end="", flush=True)
        except Exception as e:
            self.get_logger().error(f'Failed to publish: {e}')

def main(args=None):
    rclpy.init(args=args)
    
    size = int(sys.argv[1]) if len(sys.argv) > 1 else 1024 * 1024 
    freq = float(sys.argv[2]) if len(sys.argv) > 2 else 50.0
    
    blob_talker = BlobTalker(size, freq)
    rclpy.spin(blob_talker)
    blob_talker.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()
