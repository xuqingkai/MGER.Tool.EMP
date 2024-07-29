<%@Page Language="C#" Debug="true" Inherits="System.Web.UI.Page"%>
<%
//恩普的B超【G20BW】
string postString = HttpPost();
string testJSONFile = System.Web.HttpContext.Current.Server.MapPath("./test.json");
if(System.IO.File.Exists(testJSONFile)) { postString = System.IO.File.ReadAllText(testJSONFile); }
if(string.IsNullOrEmpty(postString))
{
    Response.Write("{\"code\":500,\"msg\":\"POST请求数据为空\",\"data\":{},\"params\":{}}");  
    Response.End();
}
dynamic json = ParseJSON(postString);
if(json==null)
{
    Response.Write("{\"code\":501,\"msg\":\"JSON格式错误\",\"data\":{},\"params\":{}}");  
    Response.End();
}
string barcode = json["barcode"];
if(string.IsNullOrEmpty(barcode))
{
    Response.Write("{\"code\":501,\"msg\":\"体检号(barcode)不能为空\",\"data\":{},\"params\":{}}");  
    Response.End();
}
string name = json["name"];
string sex = json["sex"]=="male"?"男":"女";
int age = json["age"];
string id = json["id"];
string parts = json["parts"];
string examDate = json["examDate"];
string description = json["description"];
string diagnosis = json["diagnosis"];

string host = System.Web.HttpContext.Current.Request.Url.ToString().Substring(0, System.Web.HttpContext.Current.Request.Url.ToString().LastIndexOf("/")+1);
string pathPrefix = System.DateTime.Now.ToString("yyyy") + "/" + barcode + "/" + name;

string data = "";
data += ",\"barcode\":\"" + barcode + "\"";
data += ",\"name\":\"" + name + "\"";
data += ",\"sex\":\"" + sex + "\"";
data += ",\"age\":\"" + age + "\"";
data += ",\"id\":\"" + id + "\"";

string resultImgType = json["resultImgType"];
string resultImg = json["resultImg"];
byte[] resultBytes = System.Convert.FromBase64String(resultImg + "");
System.IO.MemoryStream resultMemoryStream = new System.IO.MemoryStream(resultBytes);
System.Drawing.Image resultImage = System.Drawing.Image.FromStream(resultMemoryStream);
string resultImageUrl = ImageSave(pathPrefix + "." + resultImgType, resultImage);
if(!string.IsNullOrEmpty(resultImageUrl)){ resultImageUrl=host+resultImageUrl; }
data += ",\"image\":\"" + resultImageUrl + "\"";

string imageType = json["imageType"];
object[] images = json["images"];
for(int i=0; i<images.Length; i++)
{
    //Response.Write("<img src=\"data:image/jpg;base64,"+images[i] + "\">");continue;
    byte[] bytes = System.Convert.FromBase64String(images[i] + "");
    System.IO.MemoryStream memoryStream = new System.IO.MemoryStream(bytes);
    System.Drawing.Image image = System.Drawing.Image.FromStream(memoryStream);
    string imageUrl = ImageSave(pathPrefix + "_" + i + "." + imageType, image);
    if(!string.IsNullOrEmpty(imageUrl)){ imageUrl=host+imageUrl; }
    data += ",\"image"+i+"\":\"" + imageUrl + "\"";
    memoryStream.Close();
    memoryStream.Dispose();
}
string errorMessage = null;
int dataCount=0;
errorMessage = DataCount("SELECT COUNT(*) FROM [bus] WHERE barcode='" + barcode + "'", out dataCount);
if(errorMessage != null)
{
    Response.Write("{\"code\":503,\"msg\":\"" + errorMessage + "\",\"data\":{},\"params\":{}}");  
    Response.End();
}
if(dataCount>0)
{
    //Response.Write("{\"code\":504,\"msg\":\"数据已经存在\",\"data\":{},\"params\":{}}");Response.End();
    errorMessage = DataSave("UPDATE [bus] SET [name]='"+name+"',[sex]='"+sex+"',[age]="+age+",[idcard]='"+id+"',[parts]='"+parts+"',[examDate]='"+examDate+"',[description]='"+description+"',[diagnosis]='"+diagnosis+"' WHERE [barcode]='"+barcode+"';");
}
else
{
    errorMessage = DataSave("INSERT INTO [bus] ([barcode],[name],[sex],[age],[idcard],[parts],[examDate],[description],[diagnosis]) VALUES ('"+barcode+"','"+name+"','"+sex+"',"+age+",'"+id+"','"+parts+"','"+examDate+"','"+description+"','"+diagnosis+"');");
}
if(errorMessage != null)
{
    Response.Write("{\"code\":505,\"msg\":\"" + errorMessage + "\",\"data\":{},\"params\":{}}");  
    Response.End();
}

data = "{" + data.Substring(1) + "}";
Response.ContentType="application/json";
Response.Write("{\"code\":200,\"msg\":\"处理成功\",\"data\":"+data+",\"params\":{}}");  
Response.End();

%>
<script runat="server">
public static string DatabaseConnection(out System.Data.OleDb.OleDbConnection oleDbConnection)
{
    string databaseFilePath = System.Web.HttpContext.Current.Server.MapPath("./") + "/data.mdb";
    string errorMessage = null;
	oleDbConnection = new System.Data.OleDb.OleDbConnection();
    if(oleDbConnection.State != System.Data.ConnectionState.Open)
    {
        try
        {
            oleDbConnection.ConnectionString = "Provider=Microsoft.Jet.OleDb.4.0;Data Source=" + databaseFilePath + ";Persist Security Info=True;";
            oleDbConnection.Open();
        }
        catch(System.Exception e)
        {
            errorMessage = e.Message;
        }
    }
    if(oleDbConnection.State != System.Data.ConnectionState.Open)
    {
        try
        {
            oleDbConnection.ConnectionString = "Provider=Microsoft.Ace.Oledb.12.0;Data Source=" + databaseFilePath + ";Persist Security Info=True;";
            oleDbConnection.Open();
        }
        catch(System.Exception e)
        {
            errorMessage += e.Message;
        }
    }
    if(oleDbConnection.State != System.Data.ConnectionState.Open)
    {
        return errorMessage;
    }
    return null;
}
public static string HttpPost(string charset = "UTF-8")
{
    System.IO.Stream stream = System.Web.HttpContext.Current.Request.InputStream;
    stream.Position = 0;
    byte[] bytes = new byte[stream.Length];
    stream.Read(bytes, 0, bytes.Length);
    string result = System.Text.Encoding.GetEncoding(charset).GetString(bytes);
    return result;
}
public static dynamic ParseJSON(object strJSON)
{
    dynamic json = null;
    try
    {
        System.Web.Script.Serialization.JavaScriptSerializer javascriptSerializer = new System.Web.Script.Serialization.JavaScriptSerializer();
        json = javascriptSerializer.Deserialize<dynamic>(strJSON + "");
    }
    catch { }
    return json;
}
public static string DataCount(string sql, out int count)
{
    count = 0;
    System.Data.OleDb.OleDbConnection oleDbConnection;
    string errorMessage = DatabaseConnection(out oleDbConnection);
    if(errorMessage != null){ return errorMessage; }
    try
    {
        System.Data.OleDb.OleDbCommand oleDbCommand = new System.Data.OleDb.OleDbCommand(sql, oleDbConnection);
        object result = oleDbCommand.ExecuteScalar();
        oleDbConnection.Close();
        oleDbConnection.Dispose();
        count = System.Convert.ToInt32(result);
    }
    catch(System.Exception e)
    {
        return e.Message;
    }
    return null;
}
public static string DataSave(string sql)
{
    System.Data.OleDb.OleDbConnection oleDbConnection;
    string errorMessage = DatabaseConnection(out oleDbConnection);
    if(errorMessage != null){ return errorMessage; }
    try
    {
        System.Data.OleDb.OleDbCommand oleDbCommand = new System.Data.OleDb.OleDbCommand(sql, oleDbConnection);
        int rows = oleDbCommand.ExecuteNonQuery();
        oleDbConnection.Close();
        oleDbConnection.Dispose();
        if(rows < 1){ return "保存失败";}
    }
    catch(System.Exception e)
    {
        return e.Message;
    }
    return null;
}
public static string ImageSave(string path, System.Drawing.Image image)
{
    path = path.Replace("\\","/");
    try
    {
        if(path.Contains("/"))
        {
            string dir = path.Substring(0, path.LastIndexOf("/"));
            string directoryPath = null;
            foreach (string directoryName in dir.Split('/'))
            {
                directoryPath += directoryName + "/";
                if (directoryPath.Length > 1 && directoryName.Length > 0)
                {
                    string realPath = System.Web.HttpContext.Current.Server.MapPath(directoryPath);
                    if (!System.IO.Directory.Exists(realPath)) { System.IO.Directory.CreateDirectory(realPath); }
                }
            }                      
        }
        string filePath = System.Web.HttpContext.Current.Server.MapPath(path);
        switch (filePath.Substring(filePath.LastIndexOf(".")+1).ToLower())
        {
            case "jpg":
                image.Save(filePath, System.Drawing.Imaging.ImageFormat.Jpeg);
                break;
            case "png":
                image.Save(filePath, System.Drawing.Imaging.ImageFormat.Png);
                break;
            case "gif":
                image.Save(filePath, System.Drawing.Imaging.ImageFormat.Gif);
                break;
            case "bmp":
                image.Save(filePath, System.Drawing.Imaging.ImageFormat.Bmp);
                break;
            default:
                break;
        }
        return path;
    }
    catch(System.Exception e)
    {
        return null;
    }
}
</script>

