﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PSFramework.Utility
{
    /// <summary>
    /// Class that contains a value that can be updated from another runspace
    /// </summary>
    public class DynamicContentObject
    {
        #region Statics
        /// <summary>
        /// The full dictionary of dynamic objects
        /// </summary>
        private static Dictionary<string, DynamicContentObject> Values = new Dictionary<string, DynamicContentObject>();
        
        /// <summary>
        /// Sets the value of a dynamic content object, creating a new one if needed
        /// </summary>
        /// <param name="Name">The name of the object</param>
        /// <param name="Value">The value to set</param>
        public static void Set(string Name, object Value)
        {
            string low = Name.ToLower();

            if (Values.ContainsKey(low))
                Values[low].Value = Value;
            else
                Values[low] = new DynamicContentObject(low, Value);
        }

        /// <summary>
        /// Returns the Dynamic Content Object under the specified name
        /// </summary>
        /// <param name="Name">The name of the object to return</param>
        /// <returns>The Dynamic Content Object selected</returns>
        public static DynamicContentObject Get(string Name)
        {
            if (!Values.ContainsKey(Name.ToLower()))
                Values[Name.ToLower()] = new DynamicContentObject(Name.ToLower(), null);

            return Values[Name.ToLower()];
        }
        #endregion Statics

        #region object properties
        /// <summary>
        /// The value stored in this object
        /// </summary>
        public object Value;

        /// <summary>
        /// The name of the object
        /// </summary>
        public string Name;

        /// <summary>
        /// General string representation of the value
        /// </summary>
        /// <returns>The string representation of the value</returns>
        public override string ToString()
        {
            return Value.ToString();
        }

        /// <summary>
        /// Creates a named value object that can be updated in the background
        /// </summary>
        /// <param name="Name">The name of the item</param>
        /// <param name="Value">The value of the item</param>
        public DynamicContentObject(string Name, object Value)
        {
            this.Value = Value;
            this.Name = Name.ToLower();

            Values[Name.ToLower()] = this;
        }
        #endregion object properties
    }
}
