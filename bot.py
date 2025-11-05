import discord
from discord import app_commands
from discord.ext import commands
import subprocess
import random
import string
import json
import asyncio

# === BOT SETUP ===
intents = discord.Intents.default()
bot = commands.Bot(command_prefix="!", intents=intents)
tree = bot.tree  # ✅ use bot.tree instead of creating a new CommandTree


def run(cmd):
    """Run a shell command and return output."""
    return subprocess.getoutput(cmd)


@bot.event
async def on_ready():
    await tree.sync()
    print(f"✅ Logged in as {bot.user} and synced slash commands.")


# === /createvps COMMAND ===
@tree.command(name="createvps", description="Create a VPS from the test template")
async def createvps(interaction: discord.Interaction):
    await interaction.response.send_message("🧰 **Starting VPS creation...**", ephemeral=False)
    await asyncio.sleep(1)

    # Step 1: Clone from test template
    vps_name = "vps-" + "".join(random.choices(string.ascii_lowercase + string.digits, k=5))
    await interaction.edit_original_response(content=f"🧱 **Cloning template...** (`{vps_name}`)")
    clone = run(f"lxc-copy -n test -N {vps_name}")
    if "error" in clone.lower():
        await interaction.edit_original_response(content=f"❌ Error cloning template:\n```\n{clone}\n```")
        return

    # Step 2: Start container
    await interaction.edit_original_response(content=f"⚙️ **Starting container...** (`{vps_name}`)")
    run(f"lxc-start -n {vps_name}")
    await asyncio.sleep(3)

    # Step 3: Get IP
    ip = run(f"lxc-info -n {vps_name} -iH").strip()
    if not ip:
        ip = "N/A"

    # Step 4: Generate Tmate session
    await interaction.edit_original_response(content=f"🔗 **Generating tmate session...** (`{vps_name}`)")
    run(f"lxc-attach -n {vps_name} -- bash -c 'rm -f /root/tmate.json'")
    run(f"lxc-attach -n {vps_name} -- bash -c 'tmate -S /tmp/tmate.sock new-session -d'")
    run(f"lxc-attach -n {vps_name} -- bash -c 'tmate -S /tmp/tmate.sock wait tmate-ready'")
    run(f"lxc-attach -n {vps_name} -- bash -c 'tmate -S /tmp/tmate.sock display -p \"#{{tmate_ssh}}\" > /root/tmate_ssh.txt'")
    run(f"lxc-attach -n {vps_name} -- bash -c 'tmate -S /tmp/tmate.sock display -p \"#{{tmate_web}}\" > /root/tmate_web.txt'")
    run(f"lxc-attach -n {vps_name} -- bash -c 'echo \"{{\\\"ssh\\\": \\\"$(cat /root/tmate_ssh.txt)\\\", \\\"web\\\": \\\"$(cat /root/tmate_web.txt)\\\"}}\" > /root/tmate.json'")

    tmate_data = run(f"lxc-attach -n {vps_name} -- cat /root/tmate.json")
    try:
        tmate_info = json.loads(tmate_data)
        tmate_web = tmate_info.get("web", "Not found")
        tmate_ssh = tmate_info.get("ssh", "Not found")
    except Exception:
        tmate_web = "Not found"
        tmate_ssh = "Not found"

    # Step 5: Done
    msg = (
        f"✅ **VPS Created Successfully!**\n"
        f"🖥️ **Name:** `{vps_name}`\n"
        f"🌐 **IP:** `{ip}`\n"
        f"🔗 **Tmate Web:** {tmate_web}\n"
        f"💻 **Tmate SSH:** `{tmate_ssh}`"
    )
    await interaction.edit_original_response(content=msg)


# === /deletevps COMMAND ===
@tree.command(name="deletevps", description="Delete a VPS by name")
@app_commands.describe(vps_name="Name of the VPS to delete (example: vps-abc12)")
async def deletevps(interaction: discord.Interaction, vps_name: str):
    await interaction.response.send_message(f"🗑️ **Deleting VPS `{vps_name}`...**", ephemeral=False)

    stop = run(f"lxc-stop -n {vps_name}")
    destroy = run(f"lxc-destroy -n {vps_name}")

    if "error" in destroy.lower() or "no such" in destroy.lower():
        await interaction.edit_original_response(content=f"❌ Failed to delete VPS `{vps_name}`.\n```\n{destroy}\n```")
    else:
        await interaction.edit_original_response(content=f"✅ **VPS `{vps_name}` deleted successfully!**")


# === RUN BOT ===
bot.run("YOUR_BOT_TOKEN_HERE")
