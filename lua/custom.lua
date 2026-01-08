function OpenTodoListInFloatWin()
    local file_path = vim.fn.expand("~/.todo/TODO.md")
    file_path = vim.fn.fnamemodify(file_path, ":p") -- 转换为绝对路径
    file_path = file_path:gsub("\\", "/"):gsub("//", "/") -- 统一路径格式

    local dir = vim.fn.fnamemodify(file_path, ":h")
    if vim.fn.isdirectory(dir) == 0 then
        local success, err = pcall(vim.fn.mkdir, dir, "p")
        if not success then
            vim.notify("创建目录失败: "..dir.."\n错误: "..tostring(err), vim.log.levels.ERROR)
            return
        end
    end

    local target_buf = vim.fn.bufadd(file_path) -- 先注册缓冲区
    vim.fn.bufload(target_buf) -- 强制加载内容

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == target_buf then
            vim.api.nvim_set_current_win(win)
            return
        end
    end

    local ui = vim.api.nvim_list_uis()[1]
    local win_width = math.min(80, math.max(40, ui.width - 20))
    local win_height = math.min(80, math.max(10, ui.height - 10))

    local win = vim.api.nvim_open_win(target_buf, true, {
        relative = "editor",
        width = win_width,
        height = win_height,
        col = (ui.width - win_width) / 1.05,
        row = (ui.height - win_height) / 2,
        style = "minimal",
        border = "rounded",
    })

    -- Deprecated
    -- vim.api.nvim_buf_set_option(target_buf, "buftype", "")
    -- vim.api.nvim_buf_set_option(target_buf, "swapfile", true)
    -- vim.api.nvim_buf_set_option(target_buf, "bufhidden", "hide")
    -- vim.api.nvim_buf_set_option(target_buf, "filetype", "markdown")
    -- vim.api.nvim_buf_set_option(target_buf, "undolevels", 1000)
    vim.bo[target_buf].buftype = ""
    vim.bo[target_buf].swapfile = true
    vim.bo[target_buf].bufhidden = "hide"
    vim.bo[target_buf].filetype = "markdown"
    vim.bo[target_buf].undolevels = 1000

    vim.api.nvim_create_autocmd({"BufModifiedSet", "TextChanged"}, {
        buffer = target_buf,
        callback = function()
            if vim.bo[target_buf].modified then
                vim.schedule(function()
                    vim.cmd("silent! w "..vim.fn.fnameescape(file_path))
                    vim.bo[target_buf].modified = false
                end)
            end
        end
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        buffer = target_buf,
        callback = function()
            if vim.bo[target_buf].modified then
                vim.cmd("silent! w! "..vim.fn.fnameescape(file_path))
            end
        end
    })

    return { win = win, buf = target_buf }
end
