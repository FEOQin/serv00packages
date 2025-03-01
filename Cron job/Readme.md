<details>
<summary>📂 serv00部署教程</summary>

### 1. 拥有管理面板，首次登录需要输入密码，在文件代码中修改成自己喜欢的密码即可
![image](https://github.com/user-attachments/assets/b807edf8-0f61-48a8-8f65-c8eda3d5cd27)

### 2. 管理面板对cron job增加了删除和添加的功能，方便直接管理操作。添加功能分为基本模式和专家模式。

<img src="https://github.com/user-attachments/assets/92da7d91-6cce-456a-9f96-ad946c3cd960" width="700" alt="image">

<img src="https://github.com/user-attachments/assets/71c593d2-8b46-4259-84b9-bd366d55788d" width="700" alt="image">

### 3. 系统任务列表和挂起任务列表

- **系统任务列表：**

1、显示当前serv00存在的cron job配置，可以单独操作 删除

2、刷新列表按钮可以手动刷新当前serv00的cron job配置

<img src="https://github.com/user-attachments/assets/183ec469-b4ac-40e6-953d-a7ad9a229790" width="700" alt="image">

- **挂起任务列表：**

1、显示所有添加过的cron job配置方便日后操作，可以单独操作 移除 不需要的cron

2、挂起任务列表不意味着 cron job 被删除后会自动添加，需要点击 立即同步到系统

3、立即同步到系统，会立即同步添加serv00还未配置的cron job

<img src="https://github.com/user-attachments/assets/a6005976-1bd1-4d51-9ed3-64798559a246" width="700" alt="image">

- **挂起任务列表**中的配置会存放在 `cron_job.txt` 中，第一次使用会自动创建，需要给755权限
![image](https://github.com/user-attachments/assets/80719730-a828-45ab-9632-db8313d13a9a)


- 添加新任务会直接添加到serv00的**cron job**和**挂起任务列表**

## 项目展示图
</details>

<img src="https://github.com/user-attachments/assets/ac291fe8-06c2-4643-b54a-6b03f43e54a2" width="700" alt="image">
