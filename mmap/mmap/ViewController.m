//
//  ViewController.m
//  mmap
//
//  Created by wangwei on 2018/11/30.
//  Copyright © 2018 wangwei. All rights reserved.
//

#import "ViewController.h"

#include<sys/types.h>
#include<sys/stat.h>
#include<fcntl.h>
#include<unistd.h>
#include<sys/mman.h>

#import <mach/mach_time.h>

// 映射文件到内存
int MapFile( int fd , void ** outDataPtr, size_t mapSize , struct stat * stat);
// 执行文件
void ProcessFile( char * inPathName , char * string);

void ProcessFile( char * inPathName , char * string)
{
    size_t originLength;  // 原数据字节数
    size_t dataLength;    // 数据字节数
    void * dataPtr;       //
    void * start;         //
    struct stat statInfo; // 文件状态
    int fd;               // 文件
    int outError;         // 错误信息
    
    // 打开文件
    // Open the file.
    fd = open( inPathName, O_RDWR | O_CREAT, 0 );
    
    if( fd < 0 )
    {
        outError = errno;
        return;
    }
    
    // 获取文件状态
    int fsta = fstat( fd, &statInfo );
    if( fsta != 0 )
    {
        outError = errno;
        return;
    }
    
    // 需要映射的文件大小
    dataLength = strlen(string);
    originLength = statInfo.st_size;
    size_t mapsize = originLength + dataLength;
    
    
    // 文件映射到内存
    int result = MapFile(fd, &dataPtr, mapsize ,&statInfo);
    
    // 文件映射成功
    if( result == 0 )
    {
        start = dataPtr;
        dataPtr = dataPtr + statInfo.st_size;
        
        memcpy(dataPtr, string, dataLength);
        
        //        fsync(fd);
        // 关闭映射，将修改同步到磁盘上，可能会出现延迟
        //        munmap(start, mapsize);
        
        // Now close the file. The kernel doesn’t use our file descriptor.
        //        close( fd );
    }
    else
    {
        // 映射失败
        NSLog(@"映射失败");
    }
}
// MapFile

// Exit:    fd              代表文件
//          outDataPtr      映射出的文件内容
//          mapSize         映射的size
//          return value    an errno value on error (see sys/errno.h)
//                          or zero for success
//
int MapFile( int fd, void ** outDataPtr, size_t mapSize , struct stat * stat)
{
    int outError;         // 错误信息
    struct stat statInfo; // 文件状态
    
    statInfo = * stat;
    
    // Return safe values on error.
    outError = 0;
    *outDataPtr = NULL;
    
    *outDataPtr = mmap(NULL,
                       mapSize,
                       PROT_READ|PROT_WRITE,
                       MAP_FILE|MAP_SHARED,
                       fd,
                       0);
    
    // * outDataPtr 文本内容
    
    //    NSLog(@"映射出的文本内容：%s", * outDataPtr);
    if( *outDataPtr == MAP_FAILED )
    {
        outError = errno;
    }
    else
    {
        // 调整文件的大小
        ftruncate(fd, mapSize);
        fsync(fd);//刷新文件
    }
    
    return outError;
}


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *mTV;
@property (copy, nonatomic) NSString *fullpath;

@end

@implementation ViewController

- (NSString *)getfullPath {
    if (_fullpath.length == 0) {
        NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *filePath = [NSString stringWithFormat:@"%@/text.txt",path];
        self.fullpath = filePath;
    }
    return _fullpath;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    [self eventAction];
}

CGFloat LogTimeBlock (void (^block)(void)) {
    mach_timebase_info_data_t info;
    if (mach_timebase_info(&info) != KERN_SUCCESS) return -1.0;
    
    uint64_t start = mach_absolute_time ();
    block ();
    uint64_t end = mach_absolute_time ();
    uint64_t elapsed = end - start;
    
    uint64_t nanos = elapsed * info.numer / info.denom;
    return (CGFloat)nanos / NSEC_PER_SEC;
}

-  (void)eventAction {
    
    NSString *filePath = [self getfullPath];
    NSLog(@"文件路径：%@", filePath);
    
    CGFloat time = LogTimeBlock(^{
        for (int i=0; i<100; i++) {
            ProcessFile([filePath UTF8String], [[NSString stringWithFormat:@"-%d", i] UTF8String]);
        }
    });
    NSLog(@"ProcessFile writeFile %@ms", @(time));
    

    CGFloat time1 = LogTimeBlock(^{
        for (int i=0; i<100; i++) {
            // 取
            NSString *result = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
            // 存
            NSString *str = [NSString stringWithFormat:@"%@%@", result, [NSString stringWithFormat:@"-%d", i]];
            [str writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        }
    });
    NSLog(@"File writeFile %@ms", @(time1));

}
@end
