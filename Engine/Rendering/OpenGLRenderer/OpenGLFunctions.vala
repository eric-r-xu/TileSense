namespace Engine
{
	class OpenGLFunctions
	{
		private OpenGLFunctions() {}

		public static bool has_functions()
		{
			return GL.glGenVertexArrays != null;
		}

		public static void glGenVertexArrays(int amount, uint[] vao)
		{
			GL.glGenVertexArrays(amount, vao);
		}

		public static void glBindVertexArray(uint array_handle)
		{
			GL.glBindVertexArray(array_handle);
		}

		public static void glDeleteVertexArrays(int amount, uint[] vao)
		{
			GL.glDeleteVertexArrays(amount, vao);
		}
	}
}
