import rclpy
from rclpy.node import Node
from std_msgs.msg import UInt8MultiArray
import time

class SpeedMonitor(Node):
    def __init__(self):
        super().__init__('speed_monitor')
        self.subscription = self.create_subscription(
            UInt8MultiArray, 'speed_test_topic', self.listener_callback, 10)
        self.start_time = time.time()
        self.msg_count = 0
        self.total_bytes = 0
        self.last_report_time = self.start_time
        self.get_logger().info('Speed Monitor Started. Waiting for data...')

    def listener_callback(self, msg):
        self.msg_count += 1
        size = len(msg.data)
        self.total_bytes += size
        
        current_time = time.time()
        elapsed = current_time - self.last_report_time
        
        if elapsed >= 1.0:  # Report every second
            rate = self.msg_count / elapsed
            bandwidth = (self.total_bytes / (1024 * 1024)) / elapsed
            print(f"Freq: {rate:.2f} Hz | Bandwidth: {bandwidth:.2f} MB/s | Msg Size: {size/(1024*1024):.2f} MB")
            
            self.msg_count = 0
            self.total_bytes = 0
            self.last_report_time = current_time

def main(args=None):
    rclpy.init(args=args)
    monitor = SpeedMonitor()
    rclpy.spin(monitor)
    monitor.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()
