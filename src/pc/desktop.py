"""Local desktop UI. Hardware is opened only after the user clicks Connect."""
from pathlib import Path
import queue,threading,csv
import tkinter as tk
from tkinter import ttk,filedialog,messagebox
from serial.tools import list_ports
from PIL import ImageTk
import mutagen
from songid import Library
from link_protocol import render_bitmap
from live import Session

HERE=Path(__file__).resolve().parent


class App:
    def __init__(self,root):
        self.root=root;self.root.title('领航者 · 听歌识曲');self.root.geometry('1060x650')
        self.db_path=HERE/'library.sqlite3';self.events=queue.Queue();self.session=None;self.busy=False
        self.status=tk.StringVar(value='先录入歌曲，再连接开发板')
        self.title=tk.StringVar(value='等待识别');self.artist=tk.StringVar(value='')
        self.link=tk.StringVar(value='未连接');self.port=tk.StringVar()
        outer=ttk.Frame(root,padding=20);outer.pack(fill='both',expand=True)
        ttk.Label(outer,text='听歌识曲',font=('Microsoft YaHei UI',24,'bold')).pack(anchor='w')
        ttk.Label(outer,text='本地曲库匹配 · 识别歌名与演唱者 · 保留频谱与灯环').pack(anchor='w',pady=(4,14))
        tools=ttk.Frame(outer);tools.pack(fill='x')
        self.portbox=ttk.Combobox(tools,textvariable=self.port,width=44,state='readonly');self.portbox.pack(side='left')
        ttk.Button(tools,text='刷新串口',command=self.refresh_ports).pack(side='left',padx=6)
        self.connect_button=ttk.Button(tools,text='连接开发板',command=self.toggle);self.connect_button.pack(side='left')
        ttk.Label(outer,textvariable=self.link).pack(anchor='w',pady=8)
        card=ttk.LabelFrame(outer,text='识别结果',padding=18);card.pack(fill='x',pady=(0,12))
        ttk.Label(card,textvariable=self.status,font=('Microsoft YaHei UI',12)).pack(anchor='w')
        ttk.Label(card,textvariable=self.title,font=('Microsoft YaHei UI',26,'bold'),wraplength=940).pack(anchor='w',pady=8)
        ttk.Label(card,textvariable=self.artist,font=('Microsoft YaHei UI',18),wraplength=940).pack(anchor='w')
        self.preview=ttk.Label(outer);self.preview.pack(anchor='w',pady=8)
        tools2=ttk.Frame(outer);tools2.pack(fill='x',pady=6)
        ttk.Button(tools2,text='录入歌曲文件',command=self.add_file).pack(side='left')
        ttk.Button(tools2,text='导入曲库清单 CSV',command=self.import_csv).pack(side='left',padx=8)
        ttk.Button(tools2,text='刷新曲库',command=self.refresh_library).pack(side='left')
        self.table=ttk.Treeview(outer,columns=('title','artist','seconds'),show='headings',height=5)
        for col,name,width in (('title','歌名',400),('artist','演唱者',380),('seconds','时长',100)):
            self.table.heading(col,text=name);self.table.column(col,width=width)
        self.table.pack(fill='both',expand=True)
        ttk.Label(outer,text='识别范围：已录入的原版录音。首次采样 8 秒，再做一致性确认；实际延迟和 MIC 效果待上板验收。',wraplength=1000).pack(anchor='w',pady=8)
        self.refresh_ports();self.refresh_library();self.show_preview('','','等待连接开发板')
        root.protocol('WM_DELETE_WINDOW',self.close);root.after(100,self.poll)

    def refresh_ports(self):
        self.ports={f'{p.device}  {p.description}':p.device for p in list_ports.comports()}
        self.portbox['values']=list(self.ports)
        if self.port.get() not in self.ports:self.port.set(next(iter(self.ports),''))

    def refresh_library(self):
        db=Library(self.db_path)
        try:
            for item in self.table.get_children():self.table.delete(item)
            for _,title,artist,_,duration in db.tracks():self.table.insert('',tk.END,values=(title,artist,f'{duration:.1f} 秒'))
        finally:db.close()

    def toggle(self):
        if self.session:
            self.session.stop();self.session=None;self.connect_button['text']='连接开发板'
            try:
                while True:self.events.get_nowait()
            except queue.Empty:pass
            self.link.set('已断开');self.status.set('未连接开发板');self.title.set('等待识别');self.artist.set('')
            self.show_preview('','','连接断开，板端文字将在 5 秒后失效');return
        if self.busy:messagebox.showinfo('提示','请等待歌曲录入完成');return
        if self.port.get() not in self.ports:messagebox.showerror('缺少串口','请连接开发板 USB UART 接口，然后刷新串口');return
        try:
            session=Session(self.ports[self.port.get()],self.db_path,self.events.put);session.start()
            self.session=session;self.connect_button['text']='断开连接';self.status.set('等待开发板音频数据')
        except Exception as e:messagebox.showerror('连接失败',str(e))

    def add_file(self):
        if self.session or self.busy:messagebox.showinfo('提示','请先断开识别连接，再录入歌曲');return
        path=filedialog.askopenfilename(title='选择歌曲',filetypes=[('音频文件','*.wav *.flac *.mp3 *.ogg *.aiff'),('全部文件','*.*')])
        if not path:return
        guessed_title=Path(path).stem;guessed_artist=''
        try:
            tags=mutagen.File(path,easy=True)
            if tags:
                guessed_title=tags.get('title',[guessed_title])[0];guessed_artist=tags.get('artist',[''])[0]
        except Exception:pass
        dialog=tk.Toplevel(self.root);dialog.title('确认歌曲信息');dialog.transient(self.root);dialog.grab_set()
        title=tk.StringVar(value=guessed_title);artist=tk.StringVar(value=guessed_artist)
        for row,(name,var) in enumerate((('歌名',title),('演唱者',artist))):
            ttk.Label(dialog,text=name).grid(row=row,column=0,padx=12,pady=12)
            ttk.Entry(dialog,textvariable=var,width=45).grid(row=row,column=1,padx=12,pady=12)
        def submit():
            if not title.get().strip() or not artist.get().strip():messagebox.showerror('信息未填写完整','请填写歌名和演唱者',parent=dialog);return
            entry=(path,title.get(),artist.get());dialog.destroy();self.import_rows([entry])
        ttk.Button(dialog,text='确认并录入',command=submit).grid(row=2,column=1,pady=12)

    def import_csv(self):
        if self.session or self.busy:messagebox.showinfo('提示','请先断开识别连接，再录入歌曲');return
        path=filedialog.askopenfilename(title='选择曲库清单',filetypes=[('CSV 清单','*.csv')])
        if not path:return
        try:
            with open(path,encoding='utf-8-sig',newline='') as f:rows=list(csv.DictReader(f))
            entries=[]
            for row in rows:
                audio=Path(row['file']);audio=audio if audio.is_absolute() else Path(path).parent/audio
                entries.append((audio,row['title'],row['artist']))
            if not entries:raise ValueError('清单为空')
            self.import_rows(entries)
        except Exception as e:messagebox.showerror('清单格式错误',str(e))

    def import_rows(self,rows):
        self.busy=True;self.status.set('正在建立音频指纹，请稍候')
        def worker():
            db=Library(self.db_path)
            try:
                for path,title,artist in rows:db.add(path,title,artist)
                self.events.put({'library_done':len(rows)})
            except Exception as e:self.events.put({'library_error':str(e)})
            finally:db.close()
        threading.Thread(target=worker,daemon=True).start()

    def show_preview(self,title,artist,status):
        image,_=render_bitmap(title,artist,status)
        rgb=image.convert('RGB');self.preview_image=ImageTk.PhotoImage(rgb)
        self.preview.configure(image=self.preview_image)

    def poll(self):
        try:
            while True:
                e=self.events.get_nowait()
                if 'library_done' in e or 'library_error' in e:
                    self.busy=False;self.refresh_library()
                    if 'library_error' in e:messagebox.showerror('录入失败',e['library_error']);self.status.set('录入失败')
                    else:self.status.set(f"已录入 {e['library_done']} 首歌曲，可以连接开发板")
                    continue
                self.status.set(e['status']);self.title.set(e.get('title') or '等待识别')
                self.artist.set(('演唱者：'+e['artist']) if e.get('title') else e.get('artist',''))
                self.show_preview(e.get('title',''),e.get('artist',''),e['status'])
                if 'key' in e:
                    self.link.set(f"输入模式 {e['key']}  | 丢失检测 {e.get('gaps',0)} 次  | CRC 错误 {e.get('bad_crc',0)}  | 屏幕确认序号 {e.get('display_ack',65535)}")
        except queue.Empty:pass
        self.root.after(100,self.poll)

    def close(self):
        if self.session:self.session.stop()
        self.root.destroy()

if __name__=='__main__':
    root=tk.Tk();App(root);root.mainloop()
