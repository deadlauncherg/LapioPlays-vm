# bot.py
import os
import json
import random
import string
import subprocess
import asyncio
import discord
from discord import app_commands
from discord.ext import commands
from discord.ui import View, Button

# ================= CONFIG =================
BOT_TOKEN = ""
TEMPLATE_NAME = "test"
DATA_FILE = "vps_data.json"
ADMIN_IDS = {1397506807089598474}
OWNER_ID = 1397506807089598474
TMATE_WAIT_SECONDS = 30
# ==========================================

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix="!", intents=intents)
tree = bot.tree

# ======= Helper Functions =======
def run(cmd: str):
    """Run shell command and return output."""
    return subprocess.getoutput(cmd)

def save_data(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)

def load_data():
    if not os.path.exists(DATA_FILE):
        return {}
    with open(DATA_FILE) as f:
        return json.load(f)

def random_vps_name():
    return "vps-" + "".join(random.choices(string.ascii_lowercase + string.digits, k=5))

# ======= Core =======
@bot.event
async def on_ready():
    await tree.sync()
    print(f"✅ Logged in as {bot.user} (commands synced).")

# --- CREATE VPS ---
@bot.tree.command(name="create_vps", description="Create a new VPS from template (Admin only)")
@app_commands.describe(
    ram="RAM in GB",
    cores="CPU cores",
    disk="Disk size in GB",
    target_user="User to assign VPS",
    user_type="Type of user (Free/Paid)",
    duration="Duration in hours (auto delete)"
)
async def create_vps(interaction: discord.Interaction, ram: int, cores: int, disk: int, target_user: discord.User, user_type: str, duration: int):
    if interaction.user.id not in ADMIN_IDS:
        await interaction.response.send_message("⛔ You are not allowed to run this command.", ephemeral=True)
        return

    name = "vps-" + "".join(random.choices(string.ascii_lowercase + string.digits, k=5))

    await interaction.response.send_message(f"🧱 Creating VPS `{name}`...", ephemeral=False)

    try:
        # 1️⃣ Clone template
        clone = run(f"lxc-copy -n {TEMPLATE_NAME} -N {name}")
        if "error" in clone.lower():
            await interaction.followup.send(f"❌ Error cloning template:\n```\n{clone}\n```")
            return

        # 2️⃣ Apply limits in config file BEFORE start
        cfg_file = f"/var/lib/lxc/{name}/config"
        with open(cfg_file, "a") as f:
            f.write(f"\n# Resource Limits\n")
            f.write(f"lxc.cgroup2.memory.max = {ram}G\n")
            f.write(f"lxc.cgroup2.memory.swap.max = 0\n")
            f.write(f"lxc.cgroup2.cpu.max = {int(cores)*100000} 100000\n")

        # 3️⃣ Create loopback disk for /home
        img_path = f"/var/lib/lxc/{name}/home.img"
        run(f"fallocate -l {disk}G {img_path}")
        run(f"mkfs.ext4 {img_path}")
        run(f"mkdir -p /var/lib/lxc/{name}/rootfs/home")
        run(f"mount -o loop {img_path} /var/lib/lxc/{name}/rootfs/home")

        # 4️⃣ Start container
        run(f"lxc-start -n {name}")

        # 5️⃣ Wait until container is fully running
        for _ in range(30):
            pid = run(f"lxc-info -n {name} -pH").strip()
            if pid and pid != "0":
                break
            await asyncio.sleep(1)

        # Wait for network
        for _ in range(30):
            ip = run(f"lxc-info -n {name} -iH").strip()
            if ip:
                break
            await asyncio.sleep(1)
        ip = ip or "N/A"

        # 6️⃣ Start Tmate like your working method
        run(f"lxc-attach -n {name} -- bash -c 'rm -f /root/tmate.json'")
        run(f"lxc-attach -n {name} -- bash -c 'tmate -S /tmp/tmate.sock new-session -d'")
        run(f"lxc-attach -n {name} -- bash -c 'tmate -S /tmp/tmate.sock wait tmate-ready'")
        run(f"lxc-attach -n {name} -- bash -c 'tmate -S /tmp/tmate.sock display -p \"#{{tmate_ssh}}\" > /root/tmate_ssh.txt'")
        run(f"lxc-attach -n {name} -- bash -c 'tmate -S /tmp/tmate.sock display -p \"#{{tmate_web}}\" > /root/tmate_web.txt'")
        run(f"lxc-attach -n {name} -- bash -c 'echo \"{{\\\"ssh\\\": \\\"$(cat /root/tmate_ssh.txt)\\\", \\\"web\\\": \\\"$(cat /root/tmate_web.txt)\\\"}}\" > /root/tmate.json'")

        tmate_data = run(f"lxc-attach -n {name} -- cat /root/tmate.json")
        try:
            tmate_info = json.loads(tmate_data)
            tmate_web = tmate_info.get("web", "Not found")
            tmate_ssh = tmate_info.get("ssh", "Not found")
        except Exception:
            tmate_web = "Not found"
            tmate_ssh = "Not found"

        # 7️⃣ DM target user
        embed = discord.Embed(
            title="✅ Your VPS is ready!",
            description=(
                f"**Name:** `{name}`\n"
                f"**IP:** `{ip}`\n"
                f"**RAM:** `{ram} GB`\n"
                f"**CPU:** `{cores} cores`\n"
                f"**Disk:** `{disk} GB`\n"
                f"**User Type:** {user_type}\n\n"
                f"🔗 **Tmate Web:** {tmate_web}\n"
                f"💻 **Tmate SSH:** `{tmate_ssh}`"
            ),
            color=discord.Color.green()
        )
        try:
            await target_user.send(embed=embed)
        except:
            await interaction.followup.send(f"⚠️ Couldn't DM {target_user.mention}. VPS info not sent.", ephemeral=True)

        await interaction.followup.send(f"✅ VPS `{name}` created successfully for {target_user.mention}!", ephemeral=True)

        # 8️⃣ Schedule auto-delete
        async def delete_later():
            await asyncio.sleep(duration * 3600)
            run(f"lxc-stop -n {name}")
            run(f"lxc-destroy -n {name}")
            try:
                await target_user.send(f"💀 Your VPS `{name}` has expired and was deleted.")
            except:
                pass

        asyncio.create_task(delete_later())

    except Exception as e:
        await interaction.followup.send(f"❌ Failed to create VPS:\n```\n{e}\n```", ephemeral=True)

# --- LIST VPS ---
@tree.command(name="list", description="List your VPSs")
async def listvps(interaction: discord.Interaction):
    data = load_data()
    user_vps = [name for name, info in data.items() if info["user_id"] == interaction.user.id]
    if not user_vps:
        await interaction.response.send_message("🗃️ You have no VPS yet.", ephemeral=True)
        return
    msg = "\n".join([f"• `{v}` ({data[v]['ram']}MB, {data[v]['cpu']} CPU, {data[v]['disk']}GB)" for v in user_vps])
    await interaction.response.send_message(embed=discord.Embed(title="💻 Your VPSs", description=msg, color=discord.Color.blue()))

# --- DELETE VPS ---
@tree.command(name="deletevps", description="Delete a VPS by name (admin only)")
@app_commands.describe(vps_name="Name of VPS")
async def deletevps(interaction: discord.Interaction, vps_name: str):
    if interaction.user.id not in ADMIN_IDS:
        await interaction.response.send_message("🚫 Not authorized.", ephemeral=True)
        return
    run(f"lxc-stop -n {vps_name}")
    out = run(f"lxc-destroy -n {vps_name}")
    data = load_data()
    data.pop(vps_name, None)
    save_data(data)
    await interaction.response.send_message(f"🗑️ VPS `{vps_name}` deleted.")

# --- PLANS ---
@tree.command(name="plans", description="View VPS plans")
async def plans(interaction: discord.Interaction):
    embed = discord.Embed(title="💎 VPS Plans", color=discord.Color.gold())
    embed.add_field(name="💠 ₹49 Plan", value="12GB RAM • 4 CPU • 40GB Disk", inline=False)
    embed.add_field(name="💎 ₹89 Plan", value="24GB RAM • 7 CPU • 80GB Disk", inline=False)
    embed.add_field(name="🪙 Payment", value="[QR Code](https://github.com/deadlauncherg/PUFFER-PANEL-IN-FIREBASE/blob/main/qr.jpg)\nMake payment, open a ticket, and ping <@1397506807089598474>.", inline=False)
    await interaction.response.send_message(embed=embed)

# --- RUN BOT ---
bot.run(BOT_TOKEN)

