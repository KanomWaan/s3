# คู่มือการใช้งาน S3 Upload & Delete Tool

เครื่องมือสำหรับ **อัปโหลด** หรือ **ลบ** ไฟล์บน S3 โดยทำงานผ่าน Pod ใน Kubernetes (ไม่ต้องต่อ VPN หรือเปิดสิทธิ์เครื่องตัวเอง)

---

## 1. การตั้งค่า (เริ่มที่นี่ก่อน)

แก้ไขไฟล์ `makefile.json` เพื่อระบุข้อมูลที่จำเป็น:

```json
{
  "V_NGINX_NAME": "ชื่อ-pod-nginx-ของคุณ", // ชื่อ Pod ที่จะใช้รันคำสั่ง (ต้องมี kubectl access)
  "V_LOCAL_FILE_PATH": "./my-folder", // ไฟล์หรือโฟลเดอร์ในเครื่อง ที่ต้องการอัปโหลด
  "V_S3_BUCKET": "ชื่อ-bucket", // ชื่อ S3 Bucket ปลายทาง
  "V_S3_PREFIX": "folder/in/s3", // โฟลเดอร์ปลายทางใน S3 (สำหรับวางไฟล์ หรือ ลบไฟล์)
  "V_AWS_ACCESS_KEY_ID": "...", // AWS Access Key
  "V_AWS_SECRET_ACCESS_KEY": "...", // AWS Secret Key
  "V_AWS_REGION": "ap-southeast-1" // AWS Region
}
```

---

## 2. วิธีอัปโหลดไฟล์ (`make upload`)

คำสั่งนี้จะเอาไฟล์จากเครื่องคุณ (`V_LOCAL_FILE_PATH`) ขึ้นไปไว้บน S3

1.  ระบุ path ของไฟล์หรือโฟลเดอร์ใน `makefile.json` ช่อง `"V_LOCAL_FILE_PATH"`
2.  รันคำสั่ง:
    ```bash
    make upload
    ```
    - **ถ้าเป็นไฟล์**: จะอัปโหลดขึ้นไปเลย
    - **ถ้าเป็นโฟลเดอร์**: จะถูกบีบอัดเป็น `.tar.gz` ให้ก่อน แล้วค่อยอัปโหลด

---

## 3. วิธีลบไฟล์ (`make delete`)

คำสั่งนี้จะ **ลบไฟล์ทั้งหมด** ที่อยู่ในโฟลเดอร์ S3 ที่ระบุไว้

1.  ระบุ path ใน S3 ที่ต้องการลบใน `makefile.json` ช่อง `"V_S3_PREFIX"`
    - _ตัวอย่าง: ถ้าใส่ "report/2023" มันจะลบทุกไฟล์ที่ขึ้นต้นด้วย report/2023_
2.  รันคำสั่ง:
    ```bash
    make delete
    ```

---

## สิ่งที่ต้องมีในเครื่อง (Prerequisites)

1.  **kubectl**: ต้องต่อ Cluster ได้ และมีสิทธิ์ exec เข้า Pod
2.  **Go (Golang)**: ต้องติดตั้งในเครื่องเพื่อใช้ build ตัวโปรแกรมอัปโหลด
