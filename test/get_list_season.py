import requests

# https://github.com/realysy/bili-apis

#  视频合集 https://space.bilibili.com/113845524/lists/4952742?type=season
# API https://api.bilibili.com/x/polymer/web-space/seasons_archives_list

# 获取收藏夹内容明细列表 
# API https://api.bilibili.com/x/v3/fav/resource/list

# 查询音频收藏夹（默认歌单）信息 
# API https://www.bilibili.com/audio/music-service-c/web/collections/info
# API https://www.bilibili.com/audio/music-service-c/web/collections/list

# 参考项目: https://github.com/realysy/bili-apis
def get_season_content(mid, season_id, page=1, page_size=20):
    """
    获取 B 站合集内容
    :param mid: 用户ID
    :param season_id: 合集ID
    :param page: 页码
    :param page_size: 每页数量
    :return: 合集内容
    """
    # 使用B站官方合集API获取season列表数据
    # 参考: https://github.com/realysy/bili-apis
    url = "https://api.bilibili.com/x/polymer/web-space/seasons_archives_list"
    
    # 构建请求参数
    params = {
        "mid": mid,
        "season_id": season_id,
        "page_num": page,
        "page_size": page_size
    }
    
    # 添加请求头
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Referer": f"https://space.bilibili.com/{mid}/lists/{season_id}?type=season"
    }
    
    try:
        response = requests.get(url, params=params, headers=headers)
        response.raise_for_status()  # 检查请求是否成功
        data = response.json()
        return data
    except Exception as e:
        print(f"请求失败: {e}")
        print(f"请求URL: {response.url if 'response' in locals() else url}")
        if 'response' in locals():
            print(f"响应状态码: {response.status_code}")
            print(f"响应内容: {response.text[:500]}...")
        return None

# 测试调用
if __name__ == "__main__":
    # 从链接中提取参数 - 示例链接: https://space.bilibili.com/78201/lists/13859?type=season
    mid = "78201"  # 用户ID
    season_id = "13859"  # 合集ID
    
    print(f"请求参数: mid={mid}, season_id={season_id}")
    print("=" * 50)
    print("使用API: https://api.bilibili.com/x/polymer/web-space/seasons_archives_list")
    print("参考项目: https://github.com/realysy/bili-apis")
    print("=" * 50)
    
    # 调用 API
    result = get_season_content(mid, season_id)
    
    if result:
        print("API 响应:")
        print(f"状态码: {result.get('code')}")
        print(f"消息: {result.get('message')}")
        
        # 提取合集信息（适配新API的响应结构）
        data = result.get('data', {})
        archives = data.get('archives', [])
        count = data.get('total', 0)
        
        print(f"总视频数: {count}")
        print(f"当前页视频数: {len(archives)}")
        print("=" * 50)
        
        # 打印前几个视频信息
        print("视频列表:")
        for i, video in enumerate(archives[:5], 1):
            print(f"\n视频 {i}:")
            print(f"标题: {video.get('title')}")
            print(f"BV号: {video.get('bvid')}")
            print(f"AV号: {video.get('aid')}")
            print(f"时长: {video.get('duration')}")  # 注意：新API返回的是duration字段
            print(f"封面: {video.get('pic')}")
            print(f"UP主: {video.get('owner', {}).get('name')}")
    else:
        print("获取失败")


