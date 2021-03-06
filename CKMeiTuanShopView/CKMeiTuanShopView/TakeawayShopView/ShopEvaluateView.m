//
//  ShopEvaluateView.m
//  AppPark
//
//  Created by 池康 on 2018/3/2.
//

#import "ShopEvaluateView.h"
#import "ReserveEvluateCell.h"
#import "EvaluateModel.h"
#import "NewShopListModel.h"
@interface ShopEvaluateView()<UITableViewDelegate,UITableViewDataSource>
{
    NSInteger _evluateLastIndex;
    NSInteger _evaluateType;
    NSInteger       _currPage;//页数索引
    NSInteger _count;
    NSMutableArray *_dataArray;
    
    ///上拉加载相关-----
    UIActivityIndicatorView *_loadView;
    BOOL _isLoading;//是否正在加载
    BOOL  _gestureEnd;//手势是否已经结束
    BOOL _isMoreThan;
    UILabel *_noDateLab;
}
@property (nonatomic , strong) UIView *evluateItemView;


@end
@implementation ShopEvaluateView


- (UIView *)evluateItemView
{
    if (!_evluateItemView) {
        _evluateItemView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, self.width, 40)];
        _evluateItemView.backgroundColor = [UIColor whiteColor];
        NSArray *array = @[@"全部",@"推荐(0)",@"一般(0)",@"不满意(0)"];
        NSArray *prcents = @[@0.2,@0.25,@0.25,@0.30];
        CGFloat content_w = self.width - 45 - 30;
        CGFloat max_X = 10;
        for (int i = 0; i<array.count; i++) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [btn setTitle:array[i] forState:UIControlStateNormal];
            btn.backgroundColor = kColor_ButonCornerColor;
            btn.titleLabel.font =kFont(12);
            btn.layer.cornerRadius = 10;
            btn.layer.masksToBounds = YES;
            btn.tag = 10010 + i ;
            [btn addTarget:self action:@selector(evluateItemClick:) forControlEvents:UIControlEventTouchUpInside];
            CGFloat btnW = [prcents[i] floatValue];
            btn.frame = CGRectMake(max_X, 15, content_w*btnW, 20);
            max_X = btn.maxX+15;
            if (i == 0) {
                [self evluateItemClick:btn];
            }
            [_evluateItemView addSubview:btn];
        }
        UILabel *line = [UITool lineLabWithFrame:CGRectMake(0, 39, self.width, 1)];
        line.backgroundColor = kColor_bgHeaderViewColor;
        [_evluateItemView addSubview:line];
    }
    return _evluateItemView;
}

//推荐，一般，有图
- (void)evluateItemClick:(UIButton *)btn
{
    UIButton *lastBT = (UIButton *)[_evluateItemView viewWithTag:_evluateLastIndex];
    lastBT.backgroundColor = kColor_ButonCornerColor;
    btn.backgroundColor = kColor_CircleColor;
    if (_evluateLastIndex != btn.tag) {
        //切换菜单的时候，删除所有手势，禁止滑动
        [[NSNotificationCenter defaultCenter] postNotificationName:@"removeAllBehaviors" object:self];
        _evaluateType = btn.tag - 10010;
         [_dataArray removeAllObjects];
        _currPage = 1;
        [_tableView reloadData];
        _loadView.frame = CGRectMake(self.center.x - 40, 0 , 80, 50);
        [self requestGetNewShopCommList];
    }
    _evluateLastIndex  = btn.tag;
}

- (id)initWithFrame:(CGRect)frame  withGroupID:(NSString *)groupId
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        _evluateLastIndex = 10010;
        _currPage = 1;
        _dataArray = [NSMutableArray array];
        _groupId = groupId;
        [self addSubview:self.evluateItemView];
        [self createView];
        [self requestGetNewShopCommList];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gestureStateBegan:) name:@"GestureRecognizerStateBegan" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gestureStateEnd:) name:@"GestureRecognizerStateEnded" object:nil];
    }
    return self;
}

#pragma mark ---通知方法
- (void)gestureStateBegan:(NSNotification *)not{
    
    BOOL isMore = _tableView.contentOffset.y >= (_tableView.contentSize.height - _tableView.height);
    if (isMore) {
        _gestureEnd = NO;
    }
}

- (void)gestureStateEnd:(NSNotification *)not{
    //    手势已经结束
    BOOL isMore = _tableView.contentOffset.y > (_tableView.contentSize.height - _tableView.height);
    if (isMore) {
        //如果滑动的偏移量超出最大的内容范围
        CGFloat between = _tableView.contentOffset.y - (_tableView.contentSize.height - _tableView.height);
        if (between >= 70) {
            _gestureEnd = YES;
        }
    }
}

- (void)createView
{
    self.tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 40,self.width, self.height-40) style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.scrollEnabled = NO;
    self.tableView.backgroundColor = UIColorFromRGB(0xF4F4F4);
    self.tableView.tableFooterView = [UIView new];
    self.tableView.separatorColor = kColor_bgHeaderViewColor;
    self.tableView.showsVerticalScrollIndicator = NO;
    [self addSubview:self.tableView];
    
    _loadView = [[UIActivityIndicatorView alloc]init];
    [_loadView setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
    _noDateLab = [UITool createLabelWithTextColor:kColor_GrayColor textSize:12 alignment:NSTextAlignmentCenter];
    _noDateLab.text = @"—  已经到底啦  —";
    
    [self.tableView addSubview:_loadView];
    [self.tableView addSubview:_noDateLab];
}

#pragma mark - FSBaseTableViewDataSource & FSBaseTableViewDelegate  委托方法
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _dataArray.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    EvaluateModel *model = _dataArray[indexPath.row];
    
    [model calculateReserveCellHeight];
    
    return model.cellHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //评价
    static NSString *reuseID = @"evluateCell";
    ReserveEvluateCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseID];
    if (!cell) {
        cell = (ReserveEvluateCell *)[[ReserveEvluateCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseID];
        cell.separatorInset = UIEdgeInsetsMake(0, 10, 0, 10);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.cellType = 1;
    }
    EvaluateModel *model = _dataArray[indexPath.row];
    [model calculateReserveCellHeight];
    cell.model = model;
    cell.frame = CGRectMake(0, 0, kScreenWidth, model.cellHeight);
    return cell;
}


//tableview 加载完成可以调用的方法--因为tableview的cell高度不定，所以在加载完成以后重新计算高度
-(void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.row == ((NSIndexPath*)[[tableView indexPathsForVisibleRows]lastObject]).row){
        //end of loading
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_dataArray.count == _count && _count > 0) {
                _noDateLab.hidden = NO;
                _noDateLab.frame = CGRectMake( 0 , _tableView.contentSize.height , self.width, 50);
            }else{
                _noDateLab.hidden = YES;
            }
        });
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    
    if (_tableView != scrollView) {
        return;
    }
    
    if (_gestureEnd) {
        return;
    }
    BOOL isMore = _tableView.contentOffset.y > (_tableView.contentSize.height - _tableView.height);
    if (isMore) {
        
        if (_count == 0 ) {
            [_loadView stopAnimating];
            _noDateLab.hidden = YES;
        }
        
        if (_dataArray.count == _count && _count > 0) {
            [_loadView stopAnimating];
            _noDateLab.hidden = NO;
            
        }
        
        if (_dataArray.count < _count && _count > 0) {
            _noDateLab.hidden = YES;
            [_loadView startAnimating];
            _loadView.frame = CGRectMake(self.tableView.center.x - 40, _tableView.contentSize.height , 80, 50);
        }
        
        //如果滑动的偏移量超出最大的内容范围
        CGFloat between = _tableView.contentOffset.y - (_tableView.contentSize.height - _tableView.height);
        if (between >= 70) {
            if (_isMoreThan) {
                return;
            }
            _isMoreThan = YES;
            //超出这个范围就开始做上拉加载动作。
            if (!_isLoading) {
                _isLoading = YES;
                _currPage++;
                if (_dataArray.count >= _count) {
                    _currPage--;
                    [_loadView stopAnimating];
                    _isLoading = NO;
                }else{
                    [self requestGetNewShopCommList];
                }
            }
        }else{
            _isMoreThan = NO;
        }
    }
}

#pragma mark - [获取服务店铺评论列表]
//获取服务店铺评论列表
- (void)requestGetNewShopCommList
{
//    NSMutableDictionary *params = [NSMutableDictionary dictionary];
//    [params setValue:@"" forKey:@"appId"];
//    [params setValue:_groupId forKey:@"groupId"];
//    [params setValue:[NSString stringWithFormat:@"%ld",_currPage] forKey:@"currPage"];//当前页数
//    [params setValue:@"15" forKey:@"pageSize"];//每页显示最大数量
//    [params setValue:[NSString stringWithFormat:@"%ld",_evaluateType] forKey:@"type"];//评价类型:0.全部1-推荐，2-一般，3-待改善
//    [[APNetworkingManager sharedManager] wsPOST:DynamicProductURL
//                                     methodName:@"getNewShopCommList"
//                                     parameters:params
//                                        success:^(NSDictionary *dictionary) {
//                                            [_loadView stopAnimating];
//                                            BOOL retFlag = [[dictionary objectForKey:@"retFlag"] boolValue];
//                                            if (retFlag) {
//                                                //解析数据
//                                                if (!dictionary) {
//                                                    return ;
//                                                }
//                                                [self analysisData:dictionary];
//                                            }else{
//                                                //请求失败原因
//
//                                            }
//
//                                        }failure:^(NSError *error) {
//                                            [_loadView stopAnimating];
//
//                                        }];
}

- (void)analysisData:(NSDictionary *)dic
{
    if (_currPage == 1) {
        [_dataArray removeAllObjects];
    }
    
    UIButton *button2 = (UIButton *)[_evluateItemView viewWithTag:10011];
    UIButton *button3 = (UIButton *)[_evluateItemView viewWithTag:10012];
    UIButton *button4 = (UIButton *)[_evluateItemView viewWithTag:10013];
    [button2 setTitle:[NSString stringWithFormat:@"推荐(%@)",dic[@"recommendedCount"]] forState:UIControlStateNormal] ;
    [button3 setTitle:[NSString stringWithFormat:@"一般(%@)",dic[@"normalCount"]] forState:UIControlStateNormal] ;
    [button4 setTitle:[NSString stringWithFormat:@"不满意(%@)",dic[@"unsatisfyCount"]] forState:UIControlStateNormal] ;
    NSArray *productCommentList = dic[@"productCommentList"];
    //列表
    if (productCommentList.count > 0) {

        NSArray *infoArray = [EvaluateModel arrayOfModelsFromDictionaries:productCommentList error:nil];

        [_dataArray addObjectsFromArray:infoArray];
    }
    _count = [dic[@"count"] integerValue];
    [_tableView reloadData];//刷新表
   
    _isLoading = NO;
    if (_dataArray.count == 0) {
        _noDateLab.hidden = YES;
    }
}

@end
